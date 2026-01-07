"""
Git history extractor - extracts commit data from a git repository.
"""

import subprocess
import json
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Iterator, Optional
from pathlib import Path


@dataclass
class CommitData:
    """Represents a single git commit with all relevant metadata."""
    hash: str
    short_hash: str
    author_name: str
    author_email: str
    committer_name: str
    committer_email: str
    date: str  # ISO format
    timestamp: int  # Unix timestamp for sorting
    subject: str  # First line of commit message
    body: str  # Rest of commit message
    files_changed: list[str]
    insertions: int
    deletions: int
    diff_summary: str  # Condensed diff for context
    branches: list[str]  # Branches containing this commit

    def to_document(self) -> str:
        """Convert to a searchable document for memvid storage."""
        lines = [
            f"Commit: {self.short_hash} ({self.hash})",
            f"Author: {self.author_name} <{self.author_email}>",
            f"Date: {self.date}",
            f"",
            f"Subject: {self.subject}",
        ]

        if self.body:
            lines.append(f"\n{self.body}")

        lines.append(f"\nFiles changed ({len(self.files_changed)}):")
        for f in self.files_changed[:20]:  # Limit to first 20 files
            lines.append(f"  - {f}")
        if len(self.files_changed) > 20:
            lines.append(f"  ... and {len(self.files_changed) - 20} more")

        lines.append(f"\nStats: +{self.insertions} -{self.deletions}")

        if self.diff_summary:
            lines.append(f"\nChanges:\n{self.diff_summary}")

        return "\n".join(lines)

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)


def run_git(args: list[str], cwd: Optional[Path] = None) -> str:
    """Run a git command and return output."""
    result = subprocess.run(
        ["git"] + args,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout


def get_commit_diff_summary(commit_hash: str, cwd: Optional[Path] = None, max_lines: int = 100) -> str:
    """Get a condensed diff summary for a commit."""
    try:
        # Get the diff stat and a limited diff
        diff = run_git([
            "show", commit_hash,
            "--stat",
            "--format=",
            "-p",
            "--no-color"
        ], cwd=cwd)

        lines = diff.split("\n")
        if len(lines) > max_lines:
            return "\n".join(lines[:max_lines]) + f"\n... (truncated, {len(lines) - max_lines} more lines)"
        return diff
    except subprocess.CalledProcessError:
        return ""


def get_branches_containing(commit_hash: str, cwd: Optional[Path] = None) -> list[str]:
    """Get branches containing a commit."""
    try:
        output = run_git(["branch", "-a", "--contains", commit_hash], cwd=cwd)
        branches = []
        for line in output.strip().split("\n"):
            branch = line.strip().lstrip("* ")
            if branch:
                branches.append(branch)
        return branches
    except subprocess.CalledProcessError:
        return []


def extract_commits(
    repo_path: Path,
    since: Optional[str] = None,
    until: Optional[str] = None,
    branch: Optional[str] = None,
    max_commits: Optional[int] = None,
    include_diff: bool = True
) -> Iterator[CommitData]:
    """
    Extract commits from a git repository.

    Args:
        repo_path: Path to the git repository
        since: Only commits after this date (e.g., "2024-01-01")
        until: Only commits before this date
        branch: Specific branch to extract from (default: all)
        max_commits: Maximum number of commits to extract
        include_diff: Whether to include diff summaries (slower but more context)

    Yields:
        CommitData objects for each commit
    """
    # Build git log command
    # Format: hash|short_hash|author_name|author_email|committer_name|committer_email|timestamp|subject
    format_str = "%H|%h|%an|%ae|%cn|%ce|%ct|%s"

    args = [
        "log",
        f"--format={format_str}",
        "--name-only",
        "--no-merges" if not branch else ""
    ]

    if since:
        args.append(f"--since={since}")
    if until:
        args.append(f"--until={until}")
    if max_commits:
        args.append(f"-n{max_commits}")
    if branch:
        args.append(branch)

    # Filter empty args
    args = [a for a in args if a]

    try:
        output = run_git(args, cwd=repo_path)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to get git log: {e.stderr}")

    # Parse output - commits are separated by blank lines with files listed after
    current_commit = None
    current_files = []

    for line in output.split("\n"):
        if "|" in line and line.count("|") >= 7:
            # This is a commit line
            if current_commit:
                # Yield the previous commit
                yield _finalize_commit(
                    current_commit, current_files, repo_path, include_diff
                )

            parts = line.split("|", 7)
            current_commit = {
                "hash": parts[0],
                "short_hash": parts[1],
                "author_name": parts[2],
                "author_email": parts[3],
                "committer_name": parts[4],
                "committer_email": parts[5],
                "timestamp": int(parts[6]),
                "subject": parts[7] if len(parts) > 7 else ""
            }
            current_files = []
        elif line.strip() and current_commit:
            # This is a file name
            current_files.append(line.strip())

    # Don't forget the last commit
    if current_commit:
        yield _finalize_commit(
            current_commit, current_files, repo_path, include_diff
        )


def _finalize_commit(
    commit_data: dict,
    files: list[str],
    repo_path: Path,
    include_diff: bool
) -> CommitData:
    """Finalize a commit with additional data."""
    hash = commit_data["hash"]

    # Get full commit message body
    try:
        body = run_git(["log", "-1", "--format=%b", hash], cwd=repo_path).strip()
    except subprocess.CalledProcessError:
        body = ""

    # Get insertions/deletions
    try:
        stat = run_git(["show", "--stat", "--format=", hash], cwd=repo_path)
        # Parse last line like "3 files changed, 10 insertions(+), 5 deletions(-)"
        insertions = 0
        deletions = 0
        for line in stat.strip().split("\n"):
            if "insertion" in line or "deletion" in line:
                parts = line.split(",")
                for part in parts:
                    if "insertion" in part:
                        insertions = int(part.strip().split()[0])
                    elif "deletion" in part:
                        deletions = int(part.strip().split()[0])
    except (subprocess.CalledProcessError, ValueError):
        insertions = 0
        deletions = 0

    # Get diff summary if requested
    diff_summary = ""
    if include_diff:
        diff_summary = get_commit_diff_summary(hash, cwd=repo_path)

    # Get branches (can be slow, skip for large repos)
    # branches = get_branches_containing(hash, cwd=repo_path)
    branches = []  # Skip by default for performance

    return CommitData(
        hash=commit_data["hash"],
        short_hash=commit_data["short_hash"],
        author_name=commit_data["author_name"],
        author_email=commit_data["author_email"],
        committer_name=commit_data["committer_name"],
        committer_email=commit_data["committer_email"],
        date=datetime.fromtimestamp(commit_data["timestamp"]).isoformat(),
        timestamp=commit_data["timestamp"],
        subject=commit_data["subject"],
        body=body,
        files_changed=files,
        insertions=insertions,
        deletions=deletions,
        diff_summary=diff_summary,
        branches=branches
    )


if __name__ == "__main__":
    # Test extraction on current repo
    import sys

    repo = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")

    print(f"Extracting commits from {repo}...")
    for i, commit in enumerate(extract_commits(repo, max_commits=5)):
        print(f"\n{'='*60}")
        print(commit.to_document())
        if i >= 4:
            break
