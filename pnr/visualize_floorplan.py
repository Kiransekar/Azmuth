#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
"""
Visualize floorplan for Xcew Processor v1.1
Generates floorplan diagram from DEF file
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import re
import sys
import os

def parse_def_file(def_filename):
    """Parse DEF file to extract component positions"""
    components = []

    with open(def_filename, 'r') as f:
        content = f.read()

    # Look for COMPONENTS section and extract component placements
    components_section = re.search(r'COMPONENTS\s+{(.*?)}', content, re.DOTALL)
    if not components_section:
        print("No COMPONENTS section found in DEF file")
        return components

    components_text = components_section.group(1)

    # Extract component placements
    # Pattern: - <name> <type> + FIXED ( <x> <y> ) <orientation>
    comp_pattern = r'-\s+(\w+)\s+(\w+)\s+\+\s+FIXED\s+\(\s*(\d+)\s+(\d+)\s*\)\s+(\w+)'
    matches = re.findall(comp_pattern, components_text)

    for name, comp_type, x, y, orient in matches:
        # Convert microns to mm for display (DEF uses microns with 1000 units/mm)
        x_mm = int(x) / 1000000  # Convert to mm
        y_mm = int(y) / 1000000
        # Approximate size based on component type
        if 'riscv_core' in comp_type.lower():
            width, height = 1.5, 1.0  # mm
        elif 'eml' in comp_type.lower():
            width, height = 1.2, 0.8
        elif 'snn' in comp_type.lower():
            width, height = 1.0, 0.6
        elif 'nvm' in comp_type.lower():
            width, height = 0.8, 0.5
        else:
            width, height = 0.6, 0.4

        components.append({
            'name': name,
            'type': comp_type,
            'x': x_mm,
            'y': y_mm,
            'width': width,
            'height': height
        })

    return components

def draw_floorplan(components, die_width=4.2, die_height=4.2):
    """Draw the floorplan using matplotlib"""
    fig, ax = plt.subplots(1, figsize=(10, 10))

    # Draw die boundary
    die = patches.Rectangle((0, 0), die_width, die_height, linewidth=2,
                           edgecolor='black', facecolor='none', label='Die Boundary')
    ax.add_patch(die)

    # Color map for different component types
    color_map = {
        'riscv_core': '#FF6B6B',
        'eml_unit': '#4ECDC4',
        'snn_tile': '#45B7D1',
        'nvm_ctrl': '#96CEB4',
        'fault_monitor': '#FFEAA7',
        'orchestrator': '#DDA0DD',
        'body_bias_ctrl': '#98D8C8',
        'axi_lite_interconnect': '#F7DC6F',
        'policy_determinism': '#BB8FCE',
        'default': '#A9A9A9'
    }

    # Draw each component
    for comp in components:
        color = color_map.get(comp['type'], color_map['default'])
        rect = patches.Rectangle((comp['x'], comp['y']), comp['width'], comp['height'],
                               linewidth=1, edgecolor='black', facecolor=color, alpha=0.8)
        ax.add_patch(rect)

        # Add component name
        ax.text(comp['x'] + comp['width']/2, comp['y'] + comp['height']/2,
               comp['name'], ha='center', va='center', fontsize=8, fontweight='bold')

    # Set axis properties
    ax.set_xlim(0, die_width)
    ax.set_ylim(0, die_height)
    ax.set_xlabel('Width (mm)')
    ax.set_ylabel('Height (mm)')
    ax.set_title('Xcew Processor v1.1 Floorplan\nDie Size: {:.1f}mm × {:.1f}mm'.format(die_width, die_height))
    ax.grid(True, linestyle='--', alpha=0.6)

    # Add legend
    legend_elements = [patches.Patch(color=color, label=comp_type)
                      for comp_type, color in color_map.items() if comp_type != 'default']
    ax.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(1, 1))

    # Adjust layout to make room for legend
    plt.tight_layout()

    # Save the figure
    output_file = 'floorplan.png'
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Floorplan visualization saved as {output_file}")

    # Also save as SVG
    svg_file = 'floorplan.svg'
    plt.savefig(svg_file, bbox_inches='tight')
    print(f"Floorplan visualization saved as {svg_file}")

    plt.show()

def main():
    def_file = "pnr/runs/xcew_v1_1/xcew_placed.def"

    if not os.path.exists(def_file):
        print(f"DEF file not found: {def_file}")
        print("Available DEF files:")
        for root, dirs, files in os.walk("."):
            for file in files:
                if file.endswith(".def"):
                    print(f"  {os.path.join(root, file)}")
        return

    print(f"Parsing DEF file: {def_file}")
    components = parse_def_file(def_file)

    print(f"Found {len(components)} components")
    for comp in components[:5]:  # Print first 5
        print(f"  {comp['name']} ({comp['type']}): ({comp['x']:.2f}, {comp['y']:.2f})mm")
    if len(components) > 5:
        print(f"  ... and {len(components) - 5} more")

    if components:
        print("Drawing floorplan...")
        draw_floorplan(components)
    else:
        print("No components found to visualize")

if __name__ == "__main__":
    main()