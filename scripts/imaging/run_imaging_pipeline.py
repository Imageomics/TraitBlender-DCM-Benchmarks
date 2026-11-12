#!/usr/bin/env python3
"""Headless TraitBlender imaging driver (run inside Blender via Slurm).

Expects CONFIG=/path/to/job.yaml in the environment.
"""
import os

import bpy

CONFIG = os.environ["CONFIG"]

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
