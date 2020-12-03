if has('python3')
    command! -nargs=1 AvailablePython python3 <args>
    let s:available_short_python = ':py3'
else
    throw 'No python3 support present, vim-isort will be disabled'
endif

command! Isort exec("AvailablePython isort_file()")

if !exists('g:vim_isort_map')
    let g:vim_isort_map = '<C-i>'
endif

if g:vim_isort_map != ''
    execute "vnoremap <buffer>" g:vim_isort_map s:available_short_python "isort_visual()<CR>"
endif

AvailablePython <<EOF
from __future__ import print_function

import os
from functools import lru_cache
from pathlib import Path
from subprocess import CalledProcessError, check_output
from sys import version_info

import vim

isort_v4 = False
isort_v5 = False
try:
    from isort import SortImports, settings
    isort_v4 = True
except ImportError:
    try:
        from isort import Config, sort_code_string
        isort_v5 = True
    except ImportError:
        pass

isort_imported = isort_v4 or isort_v5


def count_blank_lines_at_end(lines):
    blank_lines = 0
    for line in reversed(lines):
        if line.strip():
            break
        else:
            blank_lines += 1
    return blank_lines


@lru_cache(maxsize=1)
def _get_isort_config(path):
    try:
        git_repo = check_output(["git", "rev-parse", "--show-toplevel"]).rstrip().decode("utf-8")
        git_toml = Path(f"{git_repo}/pyproject.toml")
    except CalledProcessError:
        git_toml = None
    if git_toml and git_toml.exists():
        return git_toml
    elif str(path) == "/":
        return None
    elif Path(f"{path}/pyproject.toml").exists() or Path(f"{path}/setup.cfg").exists() or Path(f"{path}/.isort.cfg").exists():
        return path
    return _get_isort_config(path.parent)


def _isort(vim_current):
    if not isort_imported:
        print(
            "No isort python module detected, you should install it. More info at https://github.com/darrikonn/vim-isort"
        )
        return

    if len(vim_current.range) > 1:
        text_range = vim_current.range
    else:
        text_range = vim_current.buffer
    settings_path = _get_isort_config(Path(vim_current.buffer.name))
    if isort_v4:
        config = settings.from_path(settings_path)
        config_overrides = {}
        if "virtual_env" in config:
            config_overrides["virtual_env"] = f"{settings_path}/{config['virtual_env']}"

        new_text = SortImports(
            file_contents="\n".join(text_range), settings_path=settings_path, **config_overrides
        ).output
    elif isort_v5:
        config = Config(settings_path=settings_path)
        if config.virtual_env:
            config = Config(config=Config, virtual_env=f"{settings_path}/{config.virtual_env}")

        new_text = sort_code_string("\n".join(text_range), config=Config)
    new_lines = new_text.split("\n")

    # remove empty lines wrongfully added
    while (
        new_lines
        and not new_lines[-1].strip()
        and count_blank_lines_at_end(text_range) < count_blank_lines_at_end(new_lines)
    ):
        del new_lines[-1]

    text_range[:] = new_lines


def isort_file():
    _isort(vim.current)


def isort_visual():
    _isort(vim.current)

EOF
