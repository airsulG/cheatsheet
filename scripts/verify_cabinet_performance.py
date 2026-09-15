#!/usr/bin/env python3
"""比较同一段正文的旧结构与新阅读区；默认模拟数据，可显式指定只读 SQLite 副本。"""
import pathlib
import platform
import subprocess
import sys


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("用法：verify_cabinet_performance.py <优化编译的 Debug DerivedData> [SQLite 副本]")
    derived = pathlib.Path(sys.argv[1]).resolve()
    products = derived / "Build/Products/Debug"
    objects = derived / f"Build/Intermediates.noindex/cheatsheet.build/Debug/cheatsheet.build/Objects-normal/{platform.machine()}"
    files = sorted(str(p) for p in objects.glob("*.o") if p.name != "cheatsheetApp.o")
    if not files:
        sys.exit("未找到 Debug 构建对象；请使用 SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_TESTABILITY=YES 构建。")
    output = derived / "cabinet-performance-checks"
    subprocess.run(["xcrun", "swiftc", "-O", "-parse-as-library", "-I", str(products),
                    str(pathlib.Path(__file__).with_name("CabinetPerformanceChecks.swift")),
                    *files, "-o", str(output)], check=True)
    args = [str(output), str(products / "cheatsheet.app/Contents/Resources/cheatsheet.momd")]
    if len(sys.argv) == 3:
        snapshot = pathlib.Path(sys.argv[2]).resolve()
        if not snapshot.is_file():
            sys.exit("指定的 SQLite 副本不存在。")
        args.append(str(snapshot))
    subprocess.run(args, check=True)


if __name__ == "__main__":
    main()
