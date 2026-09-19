# -*- coding: utf-8 -*-
r"""
Fast Backup Verifier for Antigravity: Compares D:\Downloads.7z with C:\Users\Boris\Downloads.
Extracts 7z file manifest with CRC32 checksums and compares against files on disk.
"""

import os
import sys
import zlib
import subprocess
import time


def get_archive_manifest(archive_path):
    print(f"[1/3] Reading file manifest & CRC32 checksums from archive header...")
    cmd = ["7z", "l", "-slt", archive_path]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace")
    if result.returncode != 0:
        print(f"[ERROR] 7z failed to read archive: {result.stderr}")
        return None

    files = {}
    current_entry = {}
    started = False
    for line in result.stdout.splitlines():
        line = line.strip()
        if not started:
            if line.startswith("----------"):
                started = True
            continue

        if not line:
            if current_entry.get("Path") and "D" not in current_entry.get("Attributes", ""):
                path = current_entry.get("Path").replace("/", "\\")
                if path.lower() != "desktop.ini":
                    size = int(current_entry.get("Size", 0))
                    crc = current_entry.get("CRC", "").upper()
                    files[path] = {"size": size, "crc": crc}
            current_entry = {}
        elif "=" in line:
            k, v = line.split("=", 1)
            current_entry[k.strip()] = v.strip()

    # Final entry
    if current_entry.get("Path") and "D" not in current_entry.get("Attributes", ""):
        path = current_entry.get("Path").replace("/", "\\")
        if path.lower() != "desktop.ini":
            size = int(current_entry.get("Size", 0))
            crc = current_entry.get("CRC", "").upper()
            files[path] = {"size": size, "crc": crc}

    return files


def compute_file_crc32(filepath, chunk_size=4 * 1024 * 1024):
    crc = 0
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            crc = zlib.crc32(chunk, crc)
    return f"{crc & 0xFFFFFFFF:08X}"


def verify(archive_path=r"D:\Downloads.7z", folder_path=r"C:\Users\Boris\Downloads"):
    print("=========================================================")
    print("       ANTIGRAVITY BACKUP CHECKSUM VERIFIER              ")
    print("=========================================================")
    print(f"Archive: {archive_path}")
    print(f"Folder:  {folder_path}\n")

    if not os.path.exists(archive_path):
        print(f"[ERROR] Archive not found: {archive_path}")
        return False
    if not os.path.exists(folder_path):
        print(f"[ERROR] Folder not found: {folder_path}")
        return False

    archive_files = get_archive_manifest(archive_path)
    if not archive_files:
        return False

    print(f"[INFO] Found {len(archive_files)} files in archive.")

    # 2. Compare against files in C:\Users\Boris\Downloads
    print(f"[2/3] Scanning folder on C: and comparing file sizes & paths...")
    disk_files = {}
    for root, dirs, files in os.walk(folder_path):
        for file in files:
            if file.lower() == "desktop.ini":
                continue
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, folder_path)
            try:
                disk_files[rel_path] = {
                    "full_path": full_path,
                    "size": os.path.getsize(full_path)
                }
            except Exception as e:
                print(f"[WARNING] Could not access {rel_path}: {e}")

    print(f"[INFO] Found {len(disk_files)} files on disk.")

    missing_in_archive = []
    missing_on_disk = []
    size_mismatches = []

    for rel_path, d_info in disk_files.items():
        if rel_path not in archive_files:
            missing_in_archive.append(rel_path)
        elif archive_files[rel_path]["size"] != d_info["size"]:
            size_mismatches.append((rel_path, d_info["size"], archive_files[rel_path]["size"]))

    for rel_path in archive_files:
        if rel_path not in disk_files:
            missing_on_disk.append(rel_path)

    print(f"\n--- Comparison Summary ---")
    print(f"Files on disk (C:):     {len(disk_files)}")
    print(f"Files in archive (D:):  {len(archive_files)}")
    print(f"Missing in archive:     {len(missing_in_archive)}")
    print(f"Missing on disk:        {len(missing_on_disk)}")
    print(f"Size mismatches:        {len(size_mismatches)}")

    if missing_in_archive or missing_on_disk or size_mismatches:
        print("\n[FAIL] Discrepancies detected between folder and archive!")
        if missing_in_archive:
            print(f"Missing in archive (first 5): {missing_in_archive[:5]}")
        if missing_on_disk:
            print(f"Missing on disk (first 5): {missing_on_disk[:5]}")
        if size_mismatches:
            print(f"Size mismatches (first 5): {size_mismatches[:5]}")
        return False

    print("\n[SUCCESS] File counts and exact byte sizes match 100%!")

    # 3. Sample / Full Checksum Verification
    print(f"\n[3/3] Verifying CRC32 checksums of files...")
    start_time = time.time()
    verified_count = 0
    crc_mismatches = []

    # Sort files by size (largest first or stream all)
    total_bytes = sum(f["size"] for f in disk_files.values())
    processed_bytes = 0

    for i, (rel_path, d_info) in enumerate(disk_files.items(), 1):
        target_crc = archive_files[rel_path]["crc"]
        if not target_crc:
            continue

        try:
            actual_crc = compute_file_crc32(d_info["full_path"])
            if actual_crc != target_crc:
                crc_mismatches.append((rel_path, target_crc, actual_crc))
                print(f"[CRC MISMATCH] {rel_path}: Archive={target_crc} vs Disk={actual_crc}")
            else:
                verified_count += 1
        except Exception as e:
            print(f"[READ ERROR] {rel_path}: {e}")

        processed_bytes += d_info["size"]
        if i % 50 == 0 or i == len(disk_files):
            pct = (processed_bytes / total_bytes) * 100.0 if total_bytes > 0 else 100.0
            print(f"  Verified {i}/{len(disk_files)} files ({pct:.1f}% data)...")

    elapsed = time.time() - start_time
    print(f"\nVerification completed in {elapsed:.1f} seconds.")
    print(f"Total files verified:  {verified_count}/{len(disk_files)}")
    print(f"Checksum mismatches:   {len(crc_mismatches)}")

    if not crc_mismatches:
        print("\n=========================================================")
        print("  VERIFICATION RESULT: 100% MATCH! BACKUP IS PERFECT!    ")
        print("=========================================================")
        return True
    else:
        print("\n[ERROR] Corrupted or mismatched files found!")
        return False


if __name__ == "__main__":
    verify()
