import os
import sys
from distutils.dir_util import copy_tree


def is_balanced(block):
    if block.count("(") != block.count(")"):
        return False
    if block.count("{") != block.count("}"):
        return False
    if block.count("[") != block.count("]"):
        return False
    return True


def should_add_into_current_block(line, code_block):
    # CASES:
    #   Empty line
    #   Imbalanced blocks
    #   After init() function until after next function
    #   Before last line of function until after next function
    if not is_balanced(code_block):
        return True
    if not line.strip():
        return True
    if line.strip().startswith(("'", "else", "end", "sub", "function")):
        return True
    if "sub init()" in code_block and not line.strip().startswith(("sub", "function")):
        return True
    return False


def to_code_blocks(brs_text):
    lines = brs_text.split("\n")

    blocks = []
    i = 0

    for line in lines:
        if not blocks:
            blocks.append(line)
            continue
        if should_add_into_current_block(line, blocks[-1]):
            blocks[-1] += "\n" + line
        else:
            blocks.append(line)

    return blocks

    # while i < len(lines):
    #     if lines[i].lower().startswith("sub") or lines[i].lower().startswith("function"):
    #         function = [lines[i]]
    #         j = i + 1
    #         while not (lines[j].lower().startswith("end sub") or lines[j].lower().startswith("end function")):
    #             function.append(lines[j])
    #             j += 1
    #
    #         function.append(lines[j])
    #         functions.append("\n".join(function))
    #         i = j
    #
    #     i += 1
    # return functions


def transform_block(block, starting_line_num):
    return block, starting_line_num


def transform_component(component_file):
    component_raw = open(component_file, 'r').read()
    component_name = component_file.split(os.sep)[-1].split(".")[0]
    print("\nCOMPONENT: " + component_name)

    for block in to_code_blocks(component_raw):
        print(">>>\n" + block + "\n<<<")


    blocks = []
    line_num = 1
    for block in blocks:
        transformed_block, line_num = transform_block(block, line_num)
        component_raw.replace(block, transformed_block)


    # global components
    # components.append([component_name, [1,4,5,7], 67])


def transform_main(main_file):
    main_component_lines = """m.global.testCoverage.addFields({playerscrubber: createobject("roSGNode","ContentNode")})
  m.global.testCoverage.playerscrubber.addFields({"length":774})
  for each line in [1,5,7,10,15]
    m.global.testCoverage.playerscrubber.addFields({line: 0})
  end for"""


# read input & create directory
project_dir = os.path.join(".", sys.argv[1])
if not os.path.exists(project_dir):
    print("Project not found")
    sys.exit()

coverage_dir = project_dir + "-coverage"
if not os.path.exists(coverage_dir):
    os.mkdir(coverage_dir)
    print("New directory created at {}".format(coverage_dir))

# copy files from directory
print("Copying project...")
copy_tree(project_dir, coverage_dir)
print("Finished.")

# get list of copied files
component_files = []
main_file = None
for root, dirs, files in os.walk(coverage_dir):
    if "tests" in root or "tasks" in root:  # TODO: check for tasks
        continue
    for name in files:
        if "source" in root and name == "main.brs":
            main_file = os.path.join(root, name)
        elif "components" in root and name.endswith(".brs"):
            component_files.append(os.path.join(root, name))
component_files.sort()

components = []
for component_file in component_files:
    transform_component(component_file)

print(components)