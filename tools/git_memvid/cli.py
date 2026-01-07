#!/usr/bin/env python3
"""
git-memvid CLI - Index git history for LLM context retrieval.

Usage:
    # Index a repository (JSON mode - no dependencies)
    python -m git_memvid index /path/to/repo --output ./git-memory

    # Index with memvid (requires: pip install memvid)
    python -m git_memvid index /path/to/repo --output ./git-memory --backend memvid

    # Search the indexed history
    python -m git_memvid search ./git-memory "authentication bug fix"

    # Get LLM-ready context
    python -m git_memvid context ./git-memory "how was the login feature implemented"

    # Show stats
    python -m git_memvid stats ./git-memory
"""

import argparse
import sys
import json
from pathlib import Path
from typing import Optional


def get_storage_class(backend: str):
    """Get the appropriate storage class based on backend."""
    if backend == "memvid":
        try:
            from .storage import GitMemvidStorage
            return GitMemvidStorage
        except ImportError:
            print("Error: memvid not installed. Install with: pip install memvid", file=sys.stderr)
            print("       Or use --backend json (default) for no dependencies.", file=sys.stderr)
            sys.exit(1)
    else:
        from .json_storage import GitJsonStorage
        return GitJsonStorage


def get_retriever(storage_path: Path):
    """Auto-detect and get the appropriate retriever."""
    from .json_storage import create_retriever
    return create_retriever(storage_path)


def cmd_index(args):
    """Index a git repository."""
    from .extractor import extract_commits

    repo_path = Path(args.repo).resolve()
    output_path = Path(args.output).resolve()

    if not repo_path.exists():
        print(f"Error: Repository path does not exist: {repo_path}", file=sys.stderr)
        return 1

    # Check if it's a git repo
    if not (repo_path / ".git").exists():
        print(f"Error: Not a git repository: {repo_path}", file=sys.stderr)
        return 1

    print(f"Indexing repository: {repo_path}")
    print(f"Output directory: {output_path}")
    print(f"Backend: {args.backend}")

    # Extract commits
    print("\nExtracting commits...")
    commits = list(extract_commits(
        repo_path,
        since=args.since,
        until=args.until,
        branch=args.branch,
        max_commits=args.max_commits,
        include_diff=not args.no_diff
    ))

    if not commits:
        print("No commits found matching criteria.", file=sys.stderr)
        return 1

    print(f"Found {len(commits)} commits")

    # Get repo name
    repo_name = repo_path.name

    # Build storage
    StorageClass = get_storage_class(args.backend)
    print(f"\nBuilding {args.backend} storage...")
    storage = StorageClass(output_path)
    stats = storage.build_from_commits(commits, repo_name=repo_name)

    print(f"\n✓ Successfully indexed {stats['commits_stored']} commits")
    for key, value in stats.items():
        if key != "commits_stored":
            print(f"  {key}: {value}")

    return 0


def cmd_search(args):
    """Search indexed commits."""
    storage_path = Path(args.storage).resolve()

    try:
        retriever = get_retriever(storage_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    results = retriever.search(args.query, top_k=args.top_k)

    if not results:
        print("No matching commits found.")
        return 0

    print(f"Found {len(results)} matching commits:\n")

    for i, result in enumerate(results, 1):
        score = result.get('score', 0)
        if isinstance(score, float):
            print(f"--- Result {i} (score: {score:.3f}) ---")
        else:
            print(f"--- Result {i} (score: {score}) ---")
        content = result.get('content', '')
        print(content[:500])
        if len(content) > 500:
            print("... (truncated)")
        print()

    return 0


def cmd_context(args):
    """Get LLM-ready context for a query."""
    storage_path = Path(args.storage).resolve()

    try:
        retriever = get_retriever(storage_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # JSON backend uses max_chars, memvid uses max_tokens
    if hasattr(retriever, 'get_context'):
        try:
            context = retriever.get_context(args.query, max_tokens=args.max_tokens)
        except TypeError:
            # JSON backend
            context = retriever.get_context(args.query, max_chars=args.max_tokens * 4)
    print(context)

    return 0


def cmd_stats(args):
    """Show statistics about indexed repository."""
    storage_path = Path(args.storage).resolve()

    try:
        retriever = get_retriever(storage_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    stats = retriever.get_stats()

    print("Git Memory Index Statistics")
    print("=" * 40)
    print(f"Repository: {stats.get('repo_name', 'Unknown')}")
    print(f"Total commits: {stats.get('total_commits', 'Unknown')}")
    date_range = stats.get('date_range')
    if date_range:
        print(f"Date range: {date_range.get('oldest', '?')} to {date_range.get('newest', '?')}")
    print(f"Storage path: {stats.get('storage_path', 'Unknown')}")

    # Detect backend type
    if (storage_path / "commits.mp4").exists():
        print(f"Backend: memvid")
    elif (storage_path / "commits.json").exists():
        print(f"Backend: json")

    return 0


def cmd_export(args):
    """Export indexed data as JSON for other tools."""
    storage_path = Path(args.storage).resolve()

    # Try multiple possible metadata locations
    metadata_path = None
    for name in ["commits_metadata.json", "commits.json"]:
        candidate = storage_path / name
        if candidate.exists():
            metadata_path = candidate
            break

    if not metadata_path:
        print(f"Error: No metadata found at {storage_path}", file=sys.stderr)
        return 1

    with open(metadata_path) as f:
        metadata = json.load(f)

    # Clean up internal fields
    if "commits" in metadata:
        for commit in metadata["commits"]:
            commit.pop("_document", None)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(metadata, f, indent=2)
        print(f"Exported to {args.output}")
    else:
        print(json.dumps(metadata, indent=2))

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Index git history for LLM context retrieval"
    )
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Index command
    index_parser = subparsers.add_parser(
        "index",
        help="Index a git repository"
    )
    index_parser.add_argument(
        "repo",
        help="Path to the git repository"
    )
    index_parser.add_argument(
        "--output", "-o",
        default="./git-memory",
        help="Output directory for index files (default: ./git-memory)"
    )
    index_parser.add_argument(
        "--backend",
        choices=["json", "memvid"],
        default="json",
        help="Storage backend: json (default, no deps) or memvid (semantic search)"
    )
    index_parser.add_argument(
        "--since",
        help="Only commits after this date (e.g., 2024-01-01)"
    )
    index_parser.add_argument(
        "--until",
        help="Only commits before this date"
    )
    index_parser.add_argument(
        "--branch", "-b",
        help="Specific branch to index"
    )
    index_parser.add_argument(
        "--max-commits", "-n",
        type=int,
        help="Maximum number of commits to index"
    )
    index_parser.add_argument(
        "--no-diff",
        action="store_true",
        help="Skip diff extraction (faster but less context)"
    )
    index_parser.set_defaults(func=cmd_index)

    # Search command
    search_parser = subparsers.add_parser(
        "search",
        help="Search indexed commits"
    )
    search_parser.add_argument(
        "storage",
        help="Path to git-memory directory"
    )
    search_parser.add_argument(
        "query",
        help="Search query"
    )
    search_parser.add_argument(
        "--top-k", "-k",
        type=int,
        default=5,
        help="Number of results (default: 5)"
    )
    search_parser.set_defaults(func=cmd_search)

    # Context command
    context_parser = subparsers.add_parser(
        "context",
        help="Get LLM-ready context"
    )
    context_parser.add_argument(
        "storage",
        help="Path to git-memory directory"
    )
    context_parser.add_argument(
        "query",
        help="Query to get context for"
    )
    context_parser.add_argument(
        "--max-tokens",
        type=int,
        default=4000,
        help="Maximum tokens in output (default: 4000)"
    )
    context_parser.set_defaults(func=cmd_context)

    # Stats command
    stats_parser = subparsers.add_parser(
        "stats",
        help="Show index statistics"
    )
    stats_parser.add_argument(
        "storage",
        help="Path to git-memory directory"
    )
    stats_parser.set_defaults(func=cmd_stats)

    # Export command
    export_parser = subparsers.add_parser(
        "export",
        help="Export metadata as JSON"
    )
    export_parser.add_argument(
        "storage",
        help="Path to git-memory directory"
    )
    export_parser.add_argument(
        "--output", "-o",
        help="Output file (default: stdout)"
    )
    export_parser.set_defaults(func=cmd_export)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
