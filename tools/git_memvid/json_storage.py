"""
JSON-based fallback storage - no memvid dependency required.

This provides a simple alternative when memvid isn't available.
Uses basic text search instead of semantic search.
"""

import json
import re
from pathlib import Path
from typing import Optional
from dataclasses import asdict

from .extractor import CommitData


class GitJsonStorage:
    """
    Stores git commits as searchable JSON.

    A lightweight alternative to memvid for cases where video encoding
    isn't available or needed.
    """

    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.data_path = self.output_dir / "commits.json"

    def build_from_commits(
        self,
        commits: list[CommitData],
        repo_name: str = "unknown"
    ) -> dict:
        """Build JSON storage from commits."""
        data = {
            "repo_name": repo_name,
            "total_commits": len(commits),
            "date_range": {
                "oldest": min(c.date for c in commits) if commits else None,
                "newest": max(c.date for c in commits) if commits else None
            },
            "commits": [
                {
                    **asdict(c),
                    "_document": c.to_document()  # Pre-rendered searchable text
                }
                for c in commits
            ]
        }

        with open(self.data_path, "w") as f:
            json.dump(data, f, indent=2)

        return {
            "commits_stored": len(commits),
            "data_path": str(self.data_path)
        }


class GitJsonRetriever:
    """
    Retrieves commits from JSON storage using text search.
    """

    def __init__(self, storage_dir: Path):
        self.storage_dir = Path(storage_dir)
        self.data_path = self.storage_dir / "commits.json"

        if not self.data_path.exists():
            raise FileNotFoundError(f"No JSON storage found at {storage_dir}")

        with open(self.data_path) as f:
            self.data = json.load(f)

    def search(
        self,
        query: str,
        top_k: int = 5,
        case_sensitive: bool = False
    ) -> list[dict]:
        """
        Search commits using text matching.

        Scores results based on:
        - Exact phrase matches (highest)
        - All words present
        - Partial word matches
        """
        if not case_sensitive:
            query = query.lower()

        words = query.split()
        results = []

        for commit in self.data.get("commits", []):
            doc = commit.get("_document", "")
            if not case_sensitive:
                doc = doc.lower()

            score = 0

            # Exact phrase match
            if query in doc:
                score += 10

            # All words present
            words_found = sum(1 for w in words if w in doc)
            score += words_found * 2

            # Subject match bonus
            subject = commit.get("subject", "").lower() if not case_sensitive else commit.get("subject", "")
            if any(w in subject for w in words):
                score += 5

            # Author match
            author = commit.get("author_name", "").lower() if not case_sensitive else commit.get("author_name", "")
            if any(w in author for w in words):
                score += 3

            if score > 0:
                results.append({
                    "content": commit.get("_document", ""),
                    "score": score,
                    "commit": {k: v for k, v in commit.items() if k != "_document"}
                })

        # Sort by score descending
        results.sort(key=lambda x: x["score"], reverse=True)

        return results[:top_k]

    def get_context(
        self,
        query: str,
        max_chars: int = 16000  # ~4000 tokens
    ) -> str:
        """Get formatted context for LLM prompt."""
        results = self.search(query, top_k=10)

        header = f"""## Git History Context

Repository: {self.data.get('repo_name', 'Unknown')}
Total commits indexed: {self.data.get('total_commits', 'Unknown')}
Date range: {self.data.get('date_range', {}).get('oldest', '?')} to {self.data.get('date_range', {}).get('newest', '?')}

Query: "{query}"

### Relevant Commits:

"""
        context = header
        for result in results:
            content = result["content"]
            if len(context) + len(content) > max_chars:
                # Truncate if too long
                remaining = max_chars - len(context) - 50
                if remaining > 200:
                    context += content[:remaining] + "\n... (truncated)\n"
                break
            context += content + "\n\n---\n\n"

        return context

    def search_by_author(self, author: str, top_k: int = 10) -> list[dict]:
        """Search commits by author."""
        results = []
        for commit in self.data.get("commits", []):
            if author.lower() in commit.get("author_name", "").lower():
                results.append({
                    "content": commit.get("_document", ""),
                    "score": 10,
                    "commit": {k: v for k, v in commit.items() if k != "_document"}
                })
        return results[:top_k]

    def search_by_file(self, filepath: str, top_k: int = 10) -> list[dict]:
        """Search commits that modified a file."""
        results = []
        for commit in self.data.get("commits", []):
            files = commit.get("files_changed", [])
            if any(filepath in f for f in files):
                results.append({
                    "content": commit.get("_document", ""),
                    "score": 10,
                    "commit": {k: v for k, v in commit.items() if k != "_document"}
                })
        return results[:top_k]

    def get_stats(self) -> dict:
        """Get statistics about the indexed repository."""
        return {
            "repo_name": self.data.get("repo_name"),
            "total_commits": self.data.get("total_commits"),
            "date_range": self.data.get("date_range"),
            "storage_path": str(self.storage_dir)
        }


# Convenience function to auto-detect storage type
def create_retriever(storage_dir: Path):
    """Auto-detect and create the appropriate retriever."""
    storage_dir = Path(storage_dir)

    # Check for memvid storage first
    if (storage_dir / "commits.mp4").exists():
        try:
            from .storage import GitMemvidRetriever
            return GitMemvidRetriever(storage_dir)
        except ImportError:
            pass

    # Fall back to JSON
    if (storage_dir / "commits.json").exists():
        return GitJsonRetriever(storage_dir)

    raise FileNotFoundError(f"No valid storage found at {storage_dir}")
