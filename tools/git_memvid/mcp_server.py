#!/usr/bin/env python3
"""
MCP Server for Git History Search

Exposes git commit history as searchable tools for LLM applications
like GitHub Copilot, Claude, Cursor, and other MCP-compatible clients.

Usage:
    # Run as stdio server (for most MCP clients)
    python -m git_memvid.mcp_server --storage ./git-memory

    # Run as HTTP server (for web-based clients)
    python -m git_memvid.mcp_server --storage ./git-memory --transport http --port 8080

Configuration for VS Code / Copilot (settings.json):
    {
        "mcp.servers": {
            "git-history": {
                "command": "python",
                "args": ["-m", "git_memvid.mcp_server", "--storage", "./git-memory"]
            }
        }
    }
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

try:
    from mcp.server.fastmcp import FastMCP, Context
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False

# Global retriever instance (initialized on startup)
_retriever = None
_metadata = None


def get_retriever():
    """Get the global retriever instance."""
    global _retriever
    if _retriever is None:
        raise RuntimeError("MCP server not initialized. Call init_server() first.")
    return _retriever


def init_server(storage_path: Path):
    """Initialize the retriever from storage."""
    global _retriever, _metadata

    from .json_storage import create_retriever

    storage_path = Path(storage_path)
    _retriever = create_retriever(storage_path)
    _metadata = _retriever.get_stats()


# Create the MCP server
mcp = FastMCP(
    "git-history",
    description="Search and retrieve context from git commit history"
)


@mcp.tool()
def search_commits(query: str, top_k: int = 5) -> str:
    """
    Search git commit history for commits matching a query.

    Use this to find commits related to specific features, bug fixes,
    authors, files, or any other aspect of the repository history.

    Args:
        query: Natural language search query (e.g., "authentication bug fix",
               "changes by Alice", "modifications to login.py")
        top_k: Number of results to return (default: 5)

    Returns:
        Formatted list of matching commits with details
    """
    retriever = get_retriever()
    results = retriever.search(query, top_k=top_k)

    if not results:
        return f"No commits found matching: {query}"

    output = [f"Found {len(results)} commits matching '{query}':\n"]

    for i, result in enumerate(results, 1):
        score = result.get('score', 0)
        content = result.get('content', '')

        # Truncate long content
        if len(content) > 500:
            content = content[:500] + "... (truncated)"

        output.append(f"--- Result {i} (score: {score}) ---")
        output.append(content)
        output.append("")

    return "\n".join(output)


@mcp.tool()
def get_commit_context(query: str, max_tokens: int = 4000) -> str:
    """
    Get detailed context about repository history for a specific topic.

    Use this when you need comprehensive information about how something
    was implemented, changed over time, or who worked on it.

    Args:
        query: What you want to know about (e.g., "how was authentication implemented",
               "changes to the database layer", "recent bug fixes")
        max_tokens: Maximum length of response in tokens (default: 4000)

    Returns:
        Formatted context with relevant commits, ready for LLM consumption
    """
    retriever = get_retriever()
    return retriever.get_context(query, max_tokens=max_tokens)


@mcp.tool()
def search_by_author(author: str, top_k: int = 10) -> str:
    """
    Find commits by a specific author.

    Args:
        author: Author name or email to search for
        top_k: Number of results to return (default: 10)

    Returns:
        List of commits by the specified author
    """
    retriever = get_retriever()
    results = retriever.search_by_author(author, top_k=top_k)

    if not results:
        return f"No commits found by author: {author}"

    output = [f"Found {len(results)} commits by '{author}':\n"]

    for result in results:
        content = result.get('content', '')
        if len(content) > 300:
            content = content[:300] + "..."
        output.append(content)
        output.append("---")

    return "\n".join(output)


@mcp.tool()
def search_by_file(filepath: str, top_k: int = 10) -> str:
    """
    Find commits that modified a specific file.

    Args:
        filepath: Path to the file (can be partial, e.g., "auth.py" or "src/auth")
        top_k: Number of results to return (default: 10)

    Returns:
        List of commits that touched the specified file
    """
    retriever = get_retriever()
    results = retriever.search_by_file(filepath, top_k=top_k)

    if not results:
        return f"No commits found modifying: {filepath}"

    output = [f"Found {len(results)} commits modifying '{filepath}':\n"]

    for result in results:
        content = result.get('content', '')
        if len(content) > 300:
            content = content[:300] + "..."
        output.append(content)
        output.append("---")

    return "\n".join(output)


@mcp.tool()
def get_repo_stats() -> str:
    """
    Get statistics about the indexed repository.

    Returns:
        Repository name, total commits indexed, date range, and storage info
    """
    retriever = get_retriever()
    stats = retriever.get_stats()

    return f"""Repository Statistics:
- Name: {stats.get('repo_name', 'Unknown')}
- Total commits indexed: {stats.get('total_commits', 'Unknown')}
- Date range: {stats.get('date_range', {}).get('oldest', '?')} to {stats.get('date_range', {}).get('newest', '?')}
- Storage format: {stats.get('format', 'unknown')}
- Storage path: {stats.get('storage_path', 'Unknown')}"""


@mcp.resource("git-history://stats")
def repo_stats_resource() -> str:
    """Resource providing repository statistics."""
    return get_repo_stats()


@mcp.resource("git-history://recent")
def recent_commits_resource() -> str:
    """Resource providing recent commit summaries."""
    retriever = get_retriever()
    # Search for recent activity
    results = retriever.search("recent changes", top_k=10)

    if not results:
        return "No recent commits found."

    output = ["Recent commits:\n"]
    for result in results:
        title = result.get('title', '')
        if title:
            output.append(f"- {title}")

    return "\n".join(output)


@mcp.prompt()
def investigate_feature(feature: str) -> str:
    """
    Generate a prompt for investigating how a feature was implemented.

    Args:
        feature: The feature to investigate
    """
    return f"""Please help me understand how the "{feature}" feature was implemented in this codebase.

Use the git history search tools to:
1. Find commits related to "{feature}"
2. Identify who worked on it and when
3. Understand the key changes made

Provide a summary of:
- When it was implemented
- Who contributed
- Key files and changes involved
- Any notable iterations or bug fixes"""


@mcp.prompt()
def review_author_work(author: str) -> str:
    """
    Generate a prompt for reviewing an author's contributions.

    Args:
        author: The author to review
    """
    return f"""Please review the contributions made by "{author}" to this repository.

Use the git history tools to:
1. Find all commits by {author}
2. Identify the areas of the codebase they worked on
3. Summarize their key contributions

Provide:
- A list of major features or fixes they contributed
- The parts of the codebase they're most familiar with
- Their contribution timeline"""


def main():
    if not MCP_AVAILABLE:
        print("Error: MCP SDK not installed. Install with: pip install mcp", file=sys.stderr)
        print("       For full functionality: pip install 'mcp[cli]'", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description="MCP Server for Git History Search"
    )
    parser.add_argument(
        "--storage", "-s",
        required=True,
        help="Path to git-memory directory"
    )
    parser.add_argument(
        "--transport", "-t",
        choices=["stdio", "http", "streamable-http"],
        default="stdio",
        help="Transport protocol (default: stdio)"
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=8080,
        help="Port for HTTP transport (default: 8080)"
    )

    args = parser.parse_args()

    # Initialize the retriever
    storage_path = Path(args.storage).resolve()
    if not storage_path.exists():
        print(f"Error: Storage path does not exist: {storage_path}", file=sys.stderr)
        sys.exit(1)

    try:
        init_server(storage_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    stats = get_retriever().get_stats()
    print(f"Git History MCP Server", file=sys.stderr)
    print(f"Repository: {stats.get('repo_name', 'Unknown')}", file=sys.stderr)
    print(f"Commits indexed: {stats.get('total_commits', 0)}", file=sys.stderr)
    print(f"Transport: {args.transport}", file=sys.stderr)

    # Run the server
    if args.transport == "stdio":
        mcp.run(transport="stdio")
    else:
        mcp.run(transport=args.transport, port=args.port)


if __name__ == "__main__":
    main()
