"""
Memvid storage - stores git commits in mv2 format for LLM retrieval.

Uses the new memvid-sdk with the mv2 single-file format.
"""

import json
from pathlib import Path
from typing import Optional
from dataclasses import asdict

try:
    from memvid_sdk import create, open as memvid_open
    MEMVID_AVAILABLE = True
except ImportError:
    MEMVID_AVAILABLE = False

from .extractor import CommitData


class GitMemvidStorage:
    """
    Stores git commit history in memvid mv2 format.

    Uses the memvid-sdk to create a single .mv2 file with embedded
    search indices for fast retrieval.
    """

    def __init__(self, output_dir: Path):
        """
        Initialize storage.

        Args:
            output_dir: Directory to store the mv2 file
        """
        if not MEMVID_AVAILABLE:
            raise ImportError(
                "memvid-sdk not installed. Install with: pip install memvid-sdk"
            )

        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.mv2_path = self.output_dir / "commits.mv2"
        self.metadata_path = self.output_dir / "commits_metadata.json"

    def build_from_commits(
        self,
        commits: list[CommitData],
        repo_name: str = "unknown"
    ) -> dict:
        """
        Build mv2 storage from a list of commits.

        Args:
            commits: List of CommitData objects
            repo_name: Name of the repository for metadata

        Returns:
            Statistics about the stored data
        """
        # Create new mv2 file
        mem = create(str(self.mv2_path))

        # Enable lexical search for exact matching
        mem.enable_lex()

        metadata_list = []

        for commit in commits:
            # Create the searchable document
            doc = commit.to_document()

            # Store in mv2 with metadata
            mem.put(
                title=f"{commit.short_hash}: {commit.subject[:50]}",
                label="commit",
                text=doc,
                metadata={
                    "hash": commit.hash,
                    "short_hash": commit.short_hash,
                    "author": commit.author_name,
                    "email": commit.author_email,
                    "date": commit.date,
                    "timestamp": commit.timestamp,
                    "files_changed": len(commit.files_changed),
                    "insertions": commit.insertions,
                    "deletions": commit.deletions
                }
            )

            # Store metadata for export
            metadata_list.append({
                "hash": commit.hash,
                "short_hash": commit.short_hash,
                "author": commit.author_name,
                "email": commit.author_email,
                "date": commit.date,
                "timestamp": commit.timestamp,
                "subject": commit.subject,
                "files_changed": commit.files_changed,
                "insertions": commit.insertions,
                "deletions": commit.deletions
            })

        # Save metadata separately for quick access
        full_metadata = {
            "repo_name": repo_name,
            "total_commits": len(commits),
            "date_range": {
                "oldest": min(c.date for c in commits) if commits else None,
                "newest": max(c.date for c in commits) if commits else None
            },
            "commits": metadata_list
        }

        with open(self.metadata_path, "w") as f:
            json.dump(full_metadata, f, indent=2)

        return {
            "commits_stored": len(commits),
            "mv2_path": str(self.mv2_path),
            "metadata_path": str(self.metadata_path)
        }


class GitMemvidRetriever:
    """
    Retrieves commit context from mv2 storage.

    Provides hybrid search (lexical + semantic) over git history.
    """

    def __init__(self, storage_dir: Path):
        """
        Initialize retriever from existing storage.

        Args:
            storage_dir: Directory containing mv2 file
        """
        if not MEMVID_AVAILABLE:
            raise ImportError(
                "memvid-sdk not installed. Install with: pip install memvid-sdk"
            )

        self.storage_dir = Path(storage_dir)
        self.mv2_path = self.storage_dir / "commits.mv2"
        self.metadata_path = self.storage_dir / "commits_metadata.json"

        if not self.mv2_path.exists():
            raise FileNotFoundError(f"No mv2 storage found at {storage_dir}")

        # Open existing mv2 file
        self.mem = memvid_open(str(self.mv2_path))

        # Load metadata
        if self.metadata_path.exists():
            with open(self.metadata_path) as f:
                self.metadata = json.load(f)
        else:
            self.metadata = {}

    def search(
        self,
        query: str,
        top_k: int = 5,
        mode: str = "hybrid"
    ) -> list[dict]:
        """
        Search for commits matching a query.

        Args:
            query: Natural language query (e.g., "authentication changes")
            top_k: Number of results to return
            mode: Search mode - "hybrid" (default), "lex" (lexical), or "sem" (semantic)

        Returns:
            List of matching commits with scores
        """
        # Use memvid's find method
        results = self.mem.find(query, k=top_k, mode=mode)

        output = []
        for result in results:
            output.append({
                "content": result.get("text", ""),
                "score": result.get("score", 0),
                "title": result.get("title", ""),
                "metadata": result.get("metadata", {})
            })

        return output

    def get_context(
        self,
        query: str,
        max_tokens: int = 4000,
        top_k: int = 10
    ) -> str:
        """
        Get formatted context for an LLM prompt.

        Args:
            query: The query to search for
            max_tokens: Approximate maximum tokens in output
            top_k: Number of results to include

        Returns:
            Formatted context string ready for LLM consumption
        """
        results = self.search(query, top_k=top_k)

        header = f"""## Git History Context

Repository: {self.metadata.get('repo_name', 'Unknown')}
Total commits indexed: {self.metadata.get('total_commits', 'Unknown')}
Date range: {self.metadata.get('date_range', {}).get('oldest', '?')} to {self.metadata.get('date_range', {}).get('newest', '?')}

Query: "{query}"

### Relevant Commits:

"""
        # Estimate ~4 chars per token
        max_chars = max_tokens * 4
        context = header

        for result in results:
            content = result.get("content", "")
            if len(context) + len(content) > max_chars:
                remaining = max_chars - len(context) - 50
                if remaining > 200:
                    context += content[:remaining] + "\n... (truncated)\n"
                break
            context += content + "\n\n---\n\n"

        return context

    def search_by_author(self, author: str, top_k: int = 10) -> list[dict]:
        """Search for commits by a specific author."""
        return self.search(f"author: {author}", top_k=top_k)

    def search_by_file(self, filepath: str, top_k: int = 10) -> list[dict]:
        """Search for commits that modified a specific file."""
        return self.search(f"file: {filepath}", top_k=top_k)

    def get_stats(self) -> dict:
        """Get statistics about the indexed repository."""
        return {
            "repo_name": self.metadata.get("repo_name"),
            "total_commits": self.metadata.get("total_commits"),
            "date_range": self.metadata.get("date_range"),
            "storage_path": str(self.storage_dir),
            "format": "mv2"
        }
