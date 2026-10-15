#!/usr/bin/zsh

# The successor to the deleted tunetracker.zsh.
#
# TinkerTune reaches Trilium over ETAPI. Its marker (~/.config/tinkertune/
# TINKERTUNE.md) records the URL, so a configured library needs nothing here --
# but spec §3's marker-less path (selection step 3) probes the constant
# DEFAULT_ETAPI_URL = "http://localhost:8080/etapi", and Trilium listens on
# 37840. Without this, `tinkertune setup --write-marker <noteId>` on a machine
# with no marker yet has to pass --etapi-url by hand.
#
# Set here rather than inside bin/tinkertune on purpose: a wrapper that injects
# config into its own child makes `tinkertune` and `.venv/bin/tinkertune`
# behave differently. Move to machines/<role>/ if the port ever differs per
# machine.
export TINKERTUNE_ETAPI_URL=http://localhost:37840/etapi
