#!/usr/bin/env python3
"""Rebuild runtime WebP sprites from the retained normalized GPT Image 2 masters.

Collision outlines are deliberately preserved. The original outline extraction
script is archived at legacy/tools/prepare_plushies.py for reauthoring reference.
"""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name('optimize_runtime_assets.py')),run_name='__main__')
