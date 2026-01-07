"""
Memvid storage - stores git commits in memvid format for LLM retrieval.
"""

import json
from pathlib import Path
from typing import Optional
from dataclasses import asdict

try:
    from memvid import MemvidEncoder, MemvidRetriever
    MEMVID_AVAILABLE = True
except ImportError:
    MEMVID_AVAILABLE = False

from .extractor import CommitData


class GitMemvidStorage:
    """
    Stores git commit history in memvid format.

    Uses the memvid library to encode commits as searchable video frames.
    """

    def __init__(self, output_dir: Path):
        """
        Initialize storage.

        Args:
            output_dir: Directory to store the memvid files
        """
        if not MEMVID_AVAILABLE:
            raise ImportError(
                "memvid library not installed. Install with: pip install memvid"
            )

        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.video_path = self.output_dir / "commits.mp4"
        self.index_path = self.output_dir / "commits_index.json"
        self.metadata_path = self.output_dir / "commits_metadata.json"

    def build_from_commits(
        self,
        commits: list[CommitData],
        repo_name: str = "unknown",
        chunk_size: int = 1000
    ) -> dict:
        """
        Build memvid storage from a list of commits.

        Args:
            commits: List of CommitData objects
            repo_name: Name of the repository for metadata
            chunk_size: Characters per chunk for encoding

        Returns:
            Statistics about the stored data
        """
        encoder = MemvidEncoder()

        # Create chunks from commits
        chunks = []
        metadata_list = []

        for commit in commits:
            # Create the main document
            doc = commit.to_document()
            chunks.append(doc)

            # Store metadata separately for later retrieval
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

        # Add chunks to encoder
        encoder.add_chunks(chunks)

        # Build the video
        encoder.build_video(str(self.video_path), str(self.index_path))

        # Save metadata
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
            "video_path": str(self.video_path),
            "index_path": str(self.index_path),
            "metadata_path": str(self.metadata_path)
        }


class GitMemvidRetriever:
    """
    Retrieves commit context from memvid storage.

    Provides semantic search over git history for LLM context.
    """

    def __init__(self, storage_dir: Path):
        """
        Initialize retriever from existing storage.

        Args:
            storage_dir: Directory containing memvid files
        """
        if not MEMVID_AVAILABLE:
            raise ImportError(
                "memvid library not installed. Install with: pip install memvid"
            )

        self.storage_dir = Path(storage_dir)
        self.video_path = self.storage_dir / "commits.mp4"
        self.index_path = self.storage_dir / "commits_index.json"
        self.metadata_path = self.storage_dir / "commits_metadata.json"

        if not self.video_path.exists():
            raise FileNotFoundError(f"No memvid storage found at {storage_dir}")

        self.retriever = MemvidRetriever(
            str(self.video_path),
            str(self.index_path)
        )

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
        min_score: float = 0.0
    ) -> list[dict]:
        """
        Search for commits matching a query.

        Args:
            query: Natural language query (e.g., "authentication changes")
            top_k: Number of results to return
            min_score: Minimum similarity score threshold

        Returns:
            List of matching commits with scores
        """
        results = self.retriever.search(query, top_k=top_k)

        output = []
        for chunk, score in results:
            if score >= min_score:
                output.append({
                    "content": chunk,
                    "score": score
                })

        return output

    def get_context(
        self,
        query: str,
        max_tokens: int = 4000
    ) -> str:
        """
        Get formatted context for an LLM prompt.

        Args:
            query: The query to search for
            max_tokens: Approximate maximum tokens in output

        Returns:
            Formatted context string ready for LLM consumption
        """
        context = self.retriever.get_context(query, max_tokens=max_tokens)

        header = f"""## Git History Context

Repository: {self.metadata.get('repo_name', 'Unknown')}
Total commits indexed: {self.metadata.get('total_commits', 'Unknown')}
Date range: {self.metadata.get('date_range', {}).get('oldest', '?')} to {self.metadata.get('date_range', {}).get('newest', '?')}

Query: "{query}"

### Relevant Commits:

"""
        return header + context

    def search_by_author(self, author: str, top_k: int = 10) -> list[dict]:
        """Search for commits by a specific author."""
        return self.search(f"author: {author}", top_k=top_k)

    def search_by_file(self, filepath: str, top_k: int = 10) -> list[dict]:
        """Search for commits that modified a specific file."""
        return self.search(f"file: {filepath}", top_k=top_k)

    def search_by_date_range(
        self,
        start_date: str,
        end_date: str,
        query: str = "",
        top_k: int = 10
    ) -> list[dict]:
        """Search within a date range."""
        date_query = f"date: {start_date} to {end_date}"
        if query:
            date_query = f"{query} {date_query}"
        return self.search(date_query, top_k=top_k)

    def get_stats(self) -> dict:
        """Get statistics about the indexed repository."""
        return {
            "repo_name": self.metadata.get("repo_name"),
            "total_commits": self.metadata.get("total_commits"),
            "date_range": self.metadata.get("date_range"),
            "storage_path": str(self.storage_dir)
        }
