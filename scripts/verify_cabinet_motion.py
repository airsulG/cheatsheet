#!/usr/bin/env python3
"""用同一份真实应用对象与模拟数据比较新增微动效前后的布局成本。"""
import pathlib
import platform
import subprocess
import sys

derived = pathlib.Path(sys.argv[1]).resolve()
products = derived / 'Build/Products/Debug'
objects = derived / f'Build/Intermediates.noindex/cheatsheet.build/Debug/cheatsheet.build/Objects-normal/{platform.machine()}'
files = sorted(str(p) for p in objects.glob('*.o') if p.name != 'cheatsheetApp.o')
output = derived / 'cabinet-motion-benchmark'
subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', '-I', str(products),
                str(pathlib.Path(__file__).with_name('CabinetMotionBenchmark.swift')), *files, '-o', str(output)], check=True)
subprocess.run([str(output), str(products / 'cheatsheet.app/Contents/Resources/cheatsheet.momd')], check=True)
