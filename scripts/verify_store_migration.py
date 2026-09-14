#!/usr/bin/env python3
"""把用户指定的旧库快照复制到新目录，逐字段验证迁移；不接触正式库。"""
import pathlib
import platform
import subprocess
import sys


def main():
    if len(sys.argv) != 4:
        sys.exit("用法：verify_store_migration.py <Debug DerivedData> <旧库快照目录> <不存在的目标目录>")
    derived, source, destination = [pathlib.Path(p).resolve() for p in sys.argv[1:]]
    if destination.exists() or source == destination:
        sys.exit("目标目录必须不存在；禁止原地迁移或覆盖。")
    products = derived / "Build/Products/Debug"
    objects = derived / f"Build/Intermediates.noindex/cheatsheet.build/Debug/cheatsheet.build/Objects-normal/{platform.machine()}"
    files = sorted(str(p) for p in objects.glob("*.o") if p.name != "cheatsheetApp.o")
    if not files or not (source / "cheatsheet.sqlite").is_file():
        sys.exit("缺少 Debug 对象或源数据库。")
    output = derived / "verify-store-migration"
    subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-I", str(products),
                    str(pathlib.Path(__file__).with_name("VerifyStoreMigration.swift")),
                    *files, "-o", str(output)], check=True)
    subprocess.run([str(output), str(products / "cheatsheet.app/Contents/Resources/cheatsheet.momd"),
                    str(source), str(destination)], check=True)


if __name__ == "__main__":
    main()
