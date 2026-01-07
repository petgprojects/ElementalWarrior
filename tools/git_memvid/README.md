# git-memvid

Store git commit history in [memvid](https://github.com/memvid/memvid) mv2 format for semantic search and LLM context retrieval via MCP.

## What it does

- Extracts commit history from any git repository
- Stores commits in memvid's mv2 single-file format with embedded search indices
- Enables hybrid search (lexical + semantic) over commit messages, diffs, and metadata
- Provides an **MCP server** for integration with Copilot, Claude, Cursor, and other LLM tools
- Outputs LLM-ready context for understanding repository history

## Installation

```bash
# Core dependencies
pip install memvid-sdk

# For MCP server
pip install mcp
```

## Quick Start

### 1. Index a repository

```bash
# Index the current repo
python -m git_memvid index . --output ./git-memory

# Index with options
python -m git_memvid index /path/to/repo \
    --output ./my-repo-memory \
    --since 2024-01-01 \
    --max-commits 1000
```

### 2. Search commits

```bash
# Semantic search
python -m git_memvid search ./git-memory "authentication bug fix"

# Get LLM-ready context
python -m git_memvid context ./git-memory "how was the payment feature implemented"
```

### 3. Run the MCP server

```bash
python -m git_memvid.mcp_server --storage ./git-memory
```

## MCP Server Integration

The MCP (Model Context Protocol) server exposes git history to LLM applications.

### Available Tools

| Tool | Description |
|------|-------------|
| `search_commits` | Search commit history with natural language |
| `get_commit_context` | Get detailed context for a topic |
| `search_by_author` | Find commits by a specific author |
| `search_by_file` | Find commits that modified a file |
| `get_repo_stats` | Get repository statistics |

### VS Code / GitHub Copilot

Add to your VS Code `settings.json`:

```json
{
    "mcp.servers": {
        "git-history": {
            "command": "python",
            "args": ["-m", "git_memvid.mcp_server", "--storage", "./git-memory"]
        }
    }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
    "mcpServers": {
        "git-history": {
            "command": "python",
            "args": ["-m", "git_memvid.mcp_server", "--storage", "/path/to/git-memory"]
        }
    }
}
```

### Cursor IDE

Add to `.cursor/mcp.json`:

```json
{
    "servers": {
        "git-history": {
            "command": "python",
            "args": ["-m", "git_memvid.mcp_server", "--storage", "./git-memory"]
        }
    }
}
```

### HTTP Mode (for web clients)

```bash
python -m git_memvid.mcp_server --storage ./git-memory --transport http --port 8080
```

## CLI Reference

### Index command

```bash
python -m git_memvid index <repo> [options]
```

| Option | Description |
|--------|-------------|
| `--output, -o` | Output directory (default: ./git-memory) |
| `--backend` | Storage backend: `memvid` (default) or `json` |
| `--since` | Only commits after date (e.g., 2024-01-01) |
| `--until` | Only commits before date |
| `--branch, -b` | Specific branch to index |
| `--max-commits, -n` | Maximum commits to index |
| `--no-diff` | Skip diff extraction (faster) |

### Search command

```bash
python -m git_memvid search <storage> <query> [options]
```

| Option | Description |
|--------|-------------|
| `--top-k, -k` | Number of results (default: 5) |

### Context command

```bash
python -m git_memvid context <storage> <query> [options]
```

| Option | Description |
|--------|-------------|
| `--max-tokens` | Max tokens in output (default: 4000) |

### Stats command

```bash
python -m git_memvid stats <storage>
```

## Python API

```python
from git_memvid.extractor import extract_commits
from git_memvid.storage import GitMemvidStorage, GitMemvidRetriever
from pathlib import Path

# Extract and index commits
commits = list(extract_commits(Path("/path/to/repo"), max_commits=500))
storage = GitMemvidStorage(Path("./git-memory"))
storage.build_from_commits(commits, repo_name="my-repo")

# Search later
retriever = GitMemvidRetriever(Path("./git-memory"))
results = retriever.search("authentication changes", top_k=5)

# Get LLM-ready context
context = retriever.get_context("how does the login work", max_tokens=4000)
print(context)
```

## Storage Format

The tool uses memvid's **mv2 format** - a single file containing:
- All commit data
- Lexical search index (BM25)
- Semantic vector index (embeddings)
- Crash recovery WAL
- Metadata

```
git-memory/
├── commits.mv2           # Single mv2 file with everything
└── commits_metadata.json # Quick-access metadata
```

## Data stored per commit

- Commit hash (full + short)
- Author name and email
- Date (ISO format + Unix timestamp)
- Subject + body of commit message
- Files changed list
- Insertions/deletions count
- Diff summary

## Search Modes

The mv2 format supports three search modes:

| Mode | Description |
|------|-------------|
| `hybrid` | Combines lexical + semantic (default, best results) |
| `lex` | Lexical only (exact keyword matching, fastest) |
| `sem` | Semantic only (meaning-based, finds related concepts) |

## Example Queries

```bash
# Find authentication-related changes
python -m git_memvid search ./git-memory "authentication login security"

# Find commits by author
python -m git_memvid search ./git-memory "author: Alice"

# Find changes to specific files
python -m git_memvid search ./git-memory "file: database.py migrations"

# Understand feature implementation
python -m git_memvid context ./git-memory "how was caching implemented"

# Review recent bug fixes
python -m git_memvid context ./git-memory "bug fixes in the last month"
```
