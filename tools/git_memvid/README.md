# git-memvid

Store git commit history in [memvid](https://github.com/Olow304/memvid) format for semantic search and LLM context retrieval.

## What it does

- Extracts commit history from any git repository
- Stores commits as searchable video frames using memvid's MP4-based storage
- Enables semantic search over commit messages, diffs, and metadata
- Provides LLM-ready context for understanding repository history

## Installation

```bash
pip install memvid
```

## Usage

### Index a repository

```bash
# Index the current directory
python -m git_memvid index . --output ./git-memory

# Index a specific repo with options
python -m git_memvid index /path/to/repo \
    --output ./my-repo-memory \
    --since 2024-01-01 \
    --max-commits 1000
```

### Search commits

```bash
# Semantic search
python -m git_memvid search ./git-memory "authentication bug fix"

# Search for specific patterns
python -m git_memvid search ./git-memory "refactored database layer"
```

### Get LLM context

```bash
# Get context for a query (ready to paste into LLM)
python -m git_memvid context ./git-memory "how was the payment feature implemented"

# Limit token output
python -m git_memvid context ./git-memory "API changes" --max-tokens 2000
```

### View statistics

```bash
python -m git_memvid stats ./git-memory
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

## Use with LLM sessions

### Claude Code / CLAUDE.md integration

Add to your repository's CLAUDE.md:

```markdown
## Repository History Context

To understand the history of this codebase, a git-memvid index is available at `./git-memory/`.

Query examples:
- Search: `python -m git_memvid search ./git-memory "feature X"`
- Context: `python -m git_memvid context ./git-memory "how was X implemented"`
```

### Programmatic LLM integration

```python
from git_memvid.storage import GitMemvidRetriever

def get_repo_context_for_llm(query: str) -> str:
    """Get repository history context for an LLM prompt."""
    retriever = GitMemvidRetriever("./git-memory")
    return retriever.get_context(query, max_tokens=4000)

# Use in your LLM prompt
context = get_repo_context_for_llm("authentication implementation")
prompt = f"""
{context}

Based on the repository history above, explain how authentication was implemented.
"""
```

## Data stored per commit

Each commit frame includes:
- Commit hash (full and short)
- Author name and email
- Commit date (ISO format)
- Commit message (subject + body)
- Files changed
- Insertions/deletions count
- Diff summary (optional, for more context)

## Options

### Index command options

| Option | Description |
|--------|-------------|
| `--output, -o` | Output directory (default: ./git-memory) |
| `--since` | Only commits after date (e.g., 2024-01-01) |
| `--until` | Only commits before date |
| `--branch, -b` | Specific branch to index |
| `--max-commits, -n` | Maximum commits to index |
| `--no-diff` | Skip diff extraction (faster) |

### Search/context options

| Option | Description |
|--------|-------------|
| `--top-k, -k` | Number of results (default: 5) |
| `--max-tokens` | Max tokens in context output (default: 4000) |

## How it works

1. **Extraction**: Uses `git log` to extract commit metadata and diffs
2. **Chunking**: Each commit becomes a searchable document with structured content
3. **Encoding**: memvid encodes chunks into an MP4 file with an embedding index
4. **Search**: Semantic similarity search finds relevant commits for any query
5. **Context**: Formats results for LLM consumption with repository metadata

## File structure

After indexing, the output directory contains:
```
git-memory/
├── commits.mp4          # Encoded commit data (memvid format)
├── commits_index.json   # Embedding index for search
└── commits_metadata.json # Structured metadata for all commits
```
