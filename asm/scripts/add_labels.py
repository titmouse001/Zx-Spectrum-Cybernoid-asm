#!/usr/bin/env python3
import re
import sys

def process_file(input_filename, output_filename):
    with open(input_filename, 'r') as f:
        lines = f.readlines()

    print("[INFO] Reading input file...")

    # Mapping comment address like "; $XXXX"
    addr_to_index = {}
    for idx, line in enumerate(lines):
        m = re.search(r";\s*\$([0-9A-Fa-f]+)", line)
        if m:
            addr = m.group(1).upper()
            if addr not in addr_to_index:
                addr_to_index[addr] = idx

    print(f"[INFO] Found {len(addr_to_index)} commented addresses.")

    target_addresses = {}  # key "674C" -> value "L_674C"
    jump_pattern = re.compile(
        r"\b(CALL|JP|JR|DJNZ)"       # instruction
        r"(?:\s+[A-Z]+,)?\s+"        # "NZ," or "Z,"
        r"\$([0-9A-Fa-f]+)\b"        # address
    )

    # First pass: replace operands with references
    new_lines = []
    for line in lines:
        def repl(match):
            inst = match.group(1)  # e.g. CALL, JP, etc.
            target = match.group(2).upper()
            label = f"L_{target}"
            target_addresses[target] = label  # Keep for later
            print(f"[DEBUG] Replacing {inst} ${target} -> {inst} {label}")
            return f"{inst} {label}"

        new_line = jump_pattern.sub(repl, line)
        new_lines.append(new_line)

    print(f"[INFO] Identified {len(target_addresses)} unique jump targets.")

    # Second pass: insert labels
    insertions = []
    for target, label in target_addresses.items():
        if target in addr_to_index:
            insertions.append((addr_to_index[target], label))
        else:
            sys.stderr.write(f"[WARNING] Target address ${target} not found in comments!\n")

    insertions.sort()

    print(f"[INFO] Preparing to insert {len(insertions)} labels.")

    # Insert labels in sorted order
    offset = 0
    for idx, label in insertions:
        insert_index = idx + offset
        # Check if a label with the same name is already present.
        if not re.match(r"^\s*" + re.escape(label) + r":", new_lines[insert_index]):
            new_lines.insert(insert_index, f"{label}:\n")
            offset += 1
            print(f"[DEBUG] Inserted label {label} at line {insert_index}")

    print(f"[INFO] Successfully inserted {offset} labels.")

    # Write results
    with open(output_filename, 'w') as f:
        f.writelines(new_lines)

    print(f"[INFO] Done writing {output_filename}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python add_labels.py input.asm output.asm")
        sys.exit(1)
    process_file(sys.argv[1], sys.argv[2])
