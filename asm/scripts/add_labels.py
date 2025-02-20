#!/usr/bin/env python3
import re
import sys

def process_file(input_filename, output_filename):
    with open(input_filename, 'r') as f:
        lines = f.readlines()

    # Mapping comment addresses in code lines only
    addr_to_index = {}
    for idx, line in enumerate(lines):
        # Split into code and comment parts
        code_part, _, comment_part = line.partition(';')
        
        # Only process lines with actual code (non-empty code part)
        if not code_part.strip():
            continue
            
        # Look for address markers in comments of code-bearing lines
        if m := re.search(r"\$([0-9A-Fa-f]{4})\b", comment_part):
            addr = m.group(1).upper()
            addr_to_index.setdefault(addr, idx)

    # Track targets and warnings
    target_addresses = {}
    all_targets = set()
    jump_pattern = re.compile(
        r"\b(CALL|JP|JR|DJNZ)\s*(?:([A-Z]+),\s*)?\$([0-9A-Fa-f]{4})\b"
    )

    new_lines = []
    for line in lines:
        # Skip processing comment-only lines
        if line.lstrip().startswith(';'):
            new_lines.append(line)
            continue
            
        # Process code portion
        code_part, sep, comment_part = line.partition(';')
        missing_in_line = []
        
        def repl(match):
            inst, cond, target = match.groups()
            target = target.upper()
            all_targets.add(target)
            
            if target in addr_to_index:
                label = f"L_{target}"
                target_addresses[target] = label
                replacement = f"{inst} {cond + ',' if cond else ''}{label}".replace(" ,", ",")
                return replacement
            return match.group(0)
            
        processed_code = jump_pattern.sub(repl, code_part)
        
        # Add warnings for unresolved targets
        if missing_in_line:
            warnings = "".join([f" ; WARNING: No label for ${t}" for t in missing_in_line])
            processed_code += warnings
        
        new_lines.append(processed_code + sep + comment_part)

    # Insert labels only before code-bearing lines
    insertions = []
    for target, label in target_addresses.items():
        if target in addr_to_index:
            insertions.append((addr_to_index[target], label))
    insertions.sort()

    offset = 0
    for idx, label in insertions:
        insert_idx = idx + offset
        # Verify we're inserting before a code line
        if insert_idx < len(new_lines) and not new_lines[insert_idx].lstrip().startswith(';'):
            if not re.match(rf"^\s*{label}:", new_lines[insert_idx]):
                new_lines.insert(insert_idx, f"{label}:\n")
                offset += 1

    # Write output
    with open(output_filename, 'w') as f:
        f.writelines(new_lines)

    # Generate report
    missing_targets = all_targets - addr_to_index.keys()
    print(f"""
==== SUMMARY ====
Valid code lines with address comments: {len(addr_to_index)}
Jump targets replaced with labels: {len(target_addresses)}
Labels inserted: {offset}
Unresolved targets needing attention: {len(missing_targets)}
""")

    if missing_targets:
        print("Unresolved targets (check code lines with WARNING comments):")
        for t in sorted(missing_targets):
            print(f"  • ${t}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python add_labels.py input.asm output.asm")
        sys.exit(1)
    process_file(sys.argv[1], sys.argv[2])