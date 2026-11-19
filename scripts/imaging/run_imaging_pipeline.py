#!/usr/bin/env python3
"""Headless TraitBlender imaging driver (run inside Blender via Slurm).

Expects CONFIG=/path/to/job.yaml in the environment.

RNG: TraitBlender transform samplers use numpy.random with no built-in seed.
We seed once at process start so re-runs of the same array task reproduce
the same transform sequence. Override base with TB_IMAGING_SEED (default 5678).
"""
import os
import random

import numpy as np

CONFIG = os.environ["CONFIG"]

# Reproducible appearance noise (per Slurm array task).
_seed_base = int(os.environ.get("TB_IMAGING_SEED", "5678"))
_task = int(os.environ.get("SLURM_ARRAY_TASK_ID", "0"))
_seed = _seed_base + _task
np.random.seed(_seed)
random.seed(_seed)
print(f"TraitBlender imaging RNG seed={_seed} (base={_seed_base}, task={_task})")

import bpy

print("TraitBlender: setup_scene")
bpy.ops.traitblender.setup_scene()

print(f"TraitBlender: configure_scene({CONFIG})")
bpy.ops.traitblender.configure_scene(filepath=CONFIG)

cfg = bpy.context.scene.traitblender_config
print("Active morphospace / render engine:")
print(str(cfg))

print("TraitBlender: imaging_pipeline")
bpy.ops.traitblender.imaging_pipeline()
print("TraitBlender: imaging_pipeline finished")
