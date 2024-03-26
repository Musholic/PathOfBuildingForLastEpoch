import os

extractPath = os.getenv("LE_EXTRACT_DIR")
prefabPath = extractPath + "PrefabInstance/"


def fix_and_filter_yaml_file(filepath, output_file_name):
    source_file = open(filepath, 'r')
    output_file = open(output_file_name, 'w')
    next_id = None
    discard = False

    for lineNumber, line in enumerate(source_file.readlines()):
        if line.startswith('--- !u!'):
            next_id = line.split(' ')[2]  # remove the tag, but keep file ID
            discard = False
        else:
            if not discard:
                if next_id and not line.startswith("MonoBehaviour"):
                    discard = True
                elif next_id:
                    output_file.write("--- " + next_id)
                    output_file.write(line)
                    output_file.write("  __fileId: " + next_id.replace("&", ""))
                    next_id = None
                elif not line.endswith("{fileID: 0}\n") or line.replace(" ", "").startswith("-"):
                    output_file.write(line)

    source_file.close()
    output_file.close()


def insert_newlines(string, every=128):
    return '\n'.join(string[i:i + every] for i in range(0, len(string), every))
