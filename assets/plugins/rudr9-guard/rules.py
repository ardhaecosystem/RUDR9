"""Role → allowed tool patterns. Wildcard suffix supported (planner: kanban_*)."""

import fnmatch

# Tools each role is allowed to call. Everything else is blocked.
# Wildcard: "kanban_*" matches kanban_show, kanban_complete, etc.
# "mcp_github_*" matches all GitHub MCP tools.
ROLE_ALLOWED = {
    "default": [
        "web_search", "web_extract", "read_file", "search_files",
        "delegate_task", "todo",
        "kanban_*", "mcp_github_*",
    ],
    "planner": [
        "web_search", "web_extract", "read_file", "search_files",
        "kanban_*",
    ],
    "architect": [
        "web_search", "web_extract", "read_file", "search_files",
        "skill_view", "skills_list",
        "kanban_*", "mcp_context7_*",
    ],
    "vcm": [
        "terminal", "read_file", "search_files",
        "kanban_*", "mcp_github_*",
    ],
    "builder": [
        "terminal", "read_file", "write_file", "patch", "search_files",
        "code_execution",
        "skill_view", "skills_list",
        "kanban_*", "mcp_context7_*",
    ],
    "security": [
        "web_search", "web_extract", "read_file", "search_files",
        "kanban_*",
    ],
    "performance": [
        "web_search", "web_extract", "read_file", "search_files",
        "code_execution",
        "kanban_*",
    ],
    "reviewer": [
        "web_search", "web_extract", "read_file", "search_files",
        "kanban_*", "mcp_github_*",
    ],
}


def is_allowed(profile: str, tool_name: str) -> bool:
    """Check if a profile is allowed to call a tool. Wildcard match."""
    patterns = ROLE_ALLOWED.get(profile)
    if patterns is None:
        return True  # unknown profile — don't block (toolset restrictions handle it)
    return any(fnmatch.fnmatch(tool_name, pat) for pat in patterns)