#!/usr/bin/env python3
"""用 Debug 构建的真实应用对象验证关键行为，不启动 App 或读取真实数据库。"""

import pathlib
import platform
import subprocess
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit("用法：python3 scripts/verify_core_behaviors.py <Debug 构建的 DerivedData 目录>")
    derived = pathlib.Path(sys.argv[1]).resolve()
    products = derived / "Build/Products/Debug"
    architecture = platform.machine()
    objects = derived / (
        "Build/Intermediates.noindex/cheatsheet.build/Debug/"
        f"cheatsheet.build/Objects-normal/{architecture}"
    )
    files = sorted(str(p) for p in objects.glob("*.o") if p.name != "cheatsheetApp.o")
    model = products / "cheatsheet.app/Contents/Resources/cheatsheet.momd"
    if not files or not model.exists():
        sys.exit("未找到本机架构的 Debug 构建，请先按 README 的命令构建。")
    output = derived / "core-behavior-checks"
    source = pathlib.Path(__file__).with_name("CoreBehaviorChecks.swift")
    result = subprocess.run([
        "xcrun", "swiftc", "-parse-as-library", "-I", str(products),
        str(source), *files, "-o", str(output),
    ])
    if result.returncode:
        sys.exit(result.returncode)
    fixture = pathlib.Path(__file__).resolve().parents[1] / "product-lifecycle-prompts.cheatsheet-import.json"
    result = subprocess.run([
        str(output), str(model), str(fixture),
        "-com.apple.CoreData.ConcurrencyDebug", "1",
    ])
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
