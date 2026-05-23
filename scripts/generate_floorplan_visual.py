#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
"""
Visual representation of the Xcew Processor floorplan
Based on the OpenROAD flow script specifications
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import Rectangle
import numpy as np

def draw_xcew_floorplan():
    # Create figure and axis
    fig, ax = plt.subplots(1, figsize=(12, 12))

    # Overall chip dimensions (in microns)
    chip_width = 4200
    chip_height = 4200

    # Draw the chip outline
    chip_outline = Rectangle((0, 0), chip_width, chip_height,
                            linewidth=3, edgecolor='black', facecolor='lightgray', alpha=0.3)
    ax.add_patch(chip_outline)

    # Core domain (1.2V) - occupies most of the chip
    core_x, core_y = 50, 50
    core_width, core_height = 2950, 2950  # From 50,50 to 3000,3000
    core_rect = Rectangle((core_x, core_y), core_width, core_height,
                        linewidth=2, edgecolor='blue', facecolor='lightblue', alpha=0.5, label='Core Domain (1.2V)')
    ax.add_patch(core_rect)

    # EML region within core (for SRAM macros)
    eml_x, eml_y = 100, 100
    eml_width, eml_height = 1400, 1400  # From 100,100 to 1500,1500
    eml_rect = Rectangle((eml_x, eml_y), eml_width, eml_height,
                        linewidth=2, edgecolor='red', facecolor='lightcoral', alpha=0.5, label='EML Region')
    ax.add_patch(eml_rect)

    # SNN domain (0.9V) - voltage island
    snn_x, snn_y = 3050, 50
    snn_width, snn_height = 1100, 1450  # From 3050,50 to 4150,1500
    snn_rect = Rectangle((snn_x, snn_y), snn_width, snn_height,
                        linewidth=2, edgecolor='green', facecolor='lightgreen', alpha=0.5, label='SNN Domain (0.9V)')
    ax.add_patch(snn_rect)

    # SNN memory region
    snn_mem_x, snn_mem_y = 3100, 100
    snn_mem_width, snn_mem_height = 700, 1300  # From 3100,100 to 3800,1400
    snn_mem_rect = Rectangle((snn_mem_x, snn_mem_y), snn_mem_width, snn_mem_height,
                           linewidth=2, edgecolor='darkgreen', facecolor='palegreen', alpha=0.6, label='SNN Memories')
    ax.add_patch(snn_mem_rect)

    # NVM domain (1.8V) - closer to IO
    nvm_x, nvm_y = 3050, 1550
    nvm_width, nvm_height = 1100, 2600  # From 3050,1550 to 4150,4150
    nvm_rect = Rectangle((nvm_x, nvm_y), nvm_width, nvm_height,
                        linewidth=2, edgecolor='purple', facecolor='plum', alpha=0.5, label='NVM Domain (1.8V)')
    ax.add_patch(nvm_rect)

    # NVM memory array
    nvm_array_x, nvm_array_y = 3200, 1600
    nvm_array_width, nvm_array_height = 800, 2400  # From 3200,1600 to 4000,4000
    nvm_array_rect = Rectangle((nvm_array_x, nvm_array_y), nvm_array_width, nvm_array_height,
                             linewidth=2, edgecolor='indigo', facecolor='violet', alpha=0.6, label='NVM Array')
    ax.add_patch(nvm_array_rect)

    # Power management units
    pm_x, pm_y = 200, 1600
    pm_width, pm_height = 1000, 500
    pm_rect = Rectangle((pm_x, pm_y), pm_width, pm_height,
                       linewidth=2, edgecolor='orange', facecolor='moccasin', alpha=0.5, label='Power Management')
    ax.add_patch(pm_rect)

    # Security units
    sec_x, sec_y = 1300, 1600
    sec_width, sec_height = 800, 500
    sec_rect = Rectangle((sec_x, sec_y), sec_width, sec_height,
                        linewidth=2, edgecolor='brown', facecolor='wheat', alpha=0.5, label='Security Units')
    ax.add_patch(sec_rect)

    # Core CPU complex
    cpu_x, cpu_y = 2200, 1600
    cpu_width, cpu_height = 700, 800
    cpu_rect = Rectangle((cpu_x, cpu_y), cpu_width, cpu_height,
                        linewidth=2, edgecolor='teal', facecolor='lightcyan', alpha=0.5, label='Core CPU')
    ax.add_patch(cpu_rect)

    # IO rings around the perimeter
    # Left IO
    io_left = Rectangle((0, 0), 50, chip_height,
                       linewidth=1, edgecolor='gray', facecolor='lightyellow', alpha=0.4, label='IO Ring')
    ax.add_patch(io_left)

    # Right IO
    io_right = Rectangle((4150, 0), 50, chip_height,
                        linewidth=1, edgecolor='gray', facecolor='lightyellow', alpha=0.4)
    ax.add_patch(io_right)

    # Bottom IO
    io_bottom = Rectangle((0, 0), chip_width, 50,
                         linewidth=1, edgecolor='gray', facecolor='lightyellow', alpha=0.4)
    ax.add_patch(io_bottom)

    # Top IO
    io_top = Rectangle((0, 4150), chip_width, 50,
                      linewidth=1, edgecolor='gray', facecolor='lightyellow', alpha=0.4)
    ax.add_patch(io_top)

    # Add text labels
    ax.text(chip_width/2, chip_height + 100, 'Xcew Processor Floorplan (4.2mm x 4.2mm)',
            fontsize=16, ha='center', weight='bold')

    ax.text(core_x + core_width/2, core_y + core_height/2, 'Core\n(1.2V)',
            fontsize=12, ha='center', va='center', weight='bold')

    ax.text(snn_x + snn_width/2, snn_y + snn_height/2, 'SNN\n(0.9V)',
            fontsize=12, ha='center', va='center', weight='bold')

    ax.text(nvm_x + nvm_width/2, nvm_y + nvm_height/2, 'NVM\n(1.8V)',
            fontsize=12, ha='center', va='center', weight='bold')

    ax.text(eml_x + eml_width/2, eml_y + eml_height/2, 'EML',
            fontsize=10, ha='center', va='center', weight='bold')

    ax.text(cpu_x + cpu_width/2, cpu_y + cpu_height/2, 'CPU',
            fontsize=10, ha='center', va='center', weight='bold')

    ax.text(pm_x + pm_width/2, pm_y + pm_height/2, 'PM',
            fontsize=10, ha='center', va='center', weight='bold')

    ax.text(sec_x + sec_width/2, sec_y + sec_height/2, 'SEC',
            fontsize=10, ha='center', va='center', weight='bold')

    # Add legend
    legend_elements = [
        Rectangle((0,0),1,1, facecolor='lightblue', edgecolor='blue', label='Core Domain (1.2V)'),
        Rectangle((0,0),1,1, facecolor='lightgreen', edgecolor='green', label='SNN Domain (0.9V)'),
        Rectangle((0,0),1,1, facecolor='plum', edgecolor='purple', label='NVM Domain (1.8V)'),
        Rectangle((0,0),1,1, facecolor='lightcoral', edgecolor='red', label='EML Unit'),
        Rectangle((0,0),1,1, facecolor='moccasin', edgecolor='orange', label='Power Management'),
        Rectangle((0,0),1,1, facecolor='wheat', edgecolor='brown', label='Security Units'),
        Rectangle((0,0),1,1, facecolor='lightcyan', edgecolor='teal', label='Core CPU'),
        Rectangle((0,0),1,1, facecolor='lightyellow', edgecolor='gray', label='IO Ring')
    ]

    ax.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(1, 1))

    # Set equal aspect ratio and remove axes
    ax.set_xlim(-200, chip_width + 200)
    ax.set_ylim(-200, chip_height + 200)
    ax.set_aspect('equal')
    ax.axis('off')

    # Add scale bar (1mm = 1000µm)
    scale_bar = Rectangle((100, 100), 1000, 50, linewidth=2, edgecolor='black', facecolor='black')
    ax.add_patch(scale_bar)
    ax.text(600, 200, '1mm', fontsize=10, ha='center', va='bottom')

    plt.tight_layout()
    plt.savefig('/home/kiran-sekar/NeuroRiscV/docs/xcew_floorplan.png', dpi=300, bbox_inches='tight')
    plt.show()

if __name__ == "__main__":
    draw_xcew_floorplan()