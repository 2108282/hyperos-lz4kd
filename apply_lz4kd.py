import os
import re

common_dir = "common"

def patch_file(rel_path, target_pattern, insert_content, position="after"):
    path = os.path.join(common_dir, rel_path)
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if insert_content.strip() in content:
        print(f"Already patched: {rel_path}")
        return

    m = re.search(target_pattern, content)
    if not m:
        print(f"Pattern not found in {rel_path}: {target_pattern}")
        # 追加到末尾作为兜底
        new_content = content + "\n" + insert_content + "\n"
    else:
        if position == "after":
            idx = m.end()
            new_content = content[:idx] + "\n" + insert_content + content[idx:]
        else:
            idx = m.start()
            new_content = content[:idx] + insert_content + "\n" + content[idx:]
            
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"Patched: {rel_path}")

# 1. lib/Kconfig
patch_file("lib/Kconfig", r"config\s+LZ4_DECOMPRESS\s+tristate", """
config LZ4K_COMPRESS
	tristate

config LZ4K_DECOMPRESS
	tristate

config LZ4KD_COMPRESS
	tristate

config LZ4KD_DECOMPRESS
	tristate
""")

# 2. lib/Makefile
patch_file("lib/Makefile", r"obj-\$\(CONFIG_LZ4_DECOMPRESS\)\s*\+=\s*lz4/", """
obj-$(CONFIG_LZ4K_COMPRESS) += lz4k/
obj-$(CONFIG_LZ4K_DECOMPRESS) += lz4k/
obj-$(CONFIG_LZ4KD_COMPRESS) += lz4kd/
obj-$(CONFIG_LZ4KD_DECOMPRESS) += lz4kd/
""")

# 3. crypto/Kconfig
patch_file("crypto/Kconfig", r"config\s+CRYPTO_LZ4\s+tristate[^\n]*\n(?:\s+[^\n]*\n)*", """
config CRYPTO_LZ4K
	tristate "LZ4K compression algorithm"
	select CRYPTO_ALGAPI
	select CRYPTO_ACOMP2
	select LZ4K_COMPRESS
	select LZ4K_DECOMPRESS
	help
	  This is the LZ4K algorithm.

config CRYPTO_LZ4KD
	tristate "LZ4KD compression algorithm"
	select CRYPTO_ALGAPI
	select CRYPTO_ACOMP2
	select LZ4KD_COMPRESS
	select LZ4KD_DECOMPRESS
	help
	  This is the LZ4KD algorithm.
""")

# 4. crypto/Makefile
patch_file("crypto/Makefile", r"obj-\$\(CONFIG_CRYPTO_LZ4\)\s*\+=\s*lz4\.o", """
obj-$(CONFIG_CRYPTO_LZ4K) += lz4k.o
obj-$(CONFIG_CRYPTO_LZ4KD) += lz4kd.o
""")

# 5. drivers/block/zram/Kconfig
patch_file("drivers/block/zram/Kconfig", r"config\s+ZRAM_DEF_COMP_LZ4\s+bool[^\n]*", """
config ZRAM_DEF_COMP_LZ4KD
	bool "lz4kd"
	depends on CRYPTO_LZ4KD
""")

patch_file("drivers/block/zram/Kconfig", r'default\s+"lz4"\s+if\s+ZRAM_DEF_COMP_LZ4', """	default "lz4kd" if ZRAM_DEF_COMP_LZ4KD
""")

# 6. drivers/block/zram/zcomp.c
zcomp_path = os.path.join(common_dir, "drivers/block/zram/zcomp.c")
if os.path.exists(zcomp_path):
    with open(zcomp_path, "r", encoding="utf-8") as f:
        zc = f.read()
    if '"lz4kd"' not in zc:
        zc = re.sub(
            r'(#if IS_ENABLED\(CONFIG_CRYPTO_LZ4\)\s*\n\s*"lz4",\s*\n\s*#endif)',
            r'\1\n#if IS_ENABLED(CONFIG_CRYPTO_LZ4KD)\n\t"lz4kd",\n#endif',
            zc
        )
        with open(zcomp_path, "w", encoding="utf-8") as f:
            f.write(zc)
        print("Patched: drivers/block/zram/zcomp.c")

print("All kernel sources successfully patched via apply_lz4kd.py!")
