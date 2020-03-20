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


def should_add_into_current_block(code_block):
    # CASES:
    #   Empty line & comments: handled by transforming function
    #   Imbalanced blocks
    #   After init() function until after next function
    #   Before last line of function until after next function: handled by transforming function
    if not is_balanced(code_block):
        return True

    block_last_line = code_block.split("\n")[-1]
    if "sub init()" in code_block:
        if block_last_line.strip() == "sub init()":
            return True
        if block_last_line.strip().startswith(("sub", "function")):
            return False
        return True

    if block_last_line.strip().startswith(("else", "if")):
        if "then" in block_last_line and not block_last_line.strip().endswith("then"):
            return False
        return True

    if "else" in block_last_line:
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
        if should_add_into_current_block(blocks[-1]):
            blocks[-1] += "\n" + line
        else:
            blocks.append(line)
    return blocks


def transform_block(component_name, block, line_num):
    coverage_line = "{}_markTestCoverage({}, {})"
    if not block.strip() or block.strip().startswith(("'", "end", "sub", "function")):
        return block
    if block.strip().startswith(("else", "if")):
        if "then" in block and not block.strip().endswith("then"):
            return "DO THEN HERE"
        return "DO IF ELSE HERE"
    return coverage_line.format(component_name, line_num, block.count("\n") + 1) + "\n" + block
    # return "Mark line num: " + str(line_num) + "\n" + block


def transform_component(component_file):
    mark_test_func = """sub {0}_markTestCoverage(startingIndex, lineCount)
  fields = {{}}
  for i = 0 to line_num -1
    index = (startingIndex + lineCount).toStr()
    m.global.testCoverage.{0}.[index] += 1
  end for
end sub

"""

    component_raw = open(component_file, 'r').read()
    component_name = component_file.split(os.sep)[-1].split(".")[0]
    print("\nCOMPONENT: " + component_name)

    line_num = 1
    transformed_blocks = []
    for line in to_code_blocks(component_raw):
        print(">>>\n", line, "\n<<<")
    for block in to_code_blocks(component_raw):
        transformed_block = transform_block(component_name, block, line_num)
        transformed_blocks.append(transformed_block)
        line_num += block.count("\n") + 1

    print("\n".join(transformed_blocks))
    # blocks = []
    # for block in blocks:
    #     transformed_block, line_num = transform_block(block, line_num)
    #     component_raw.replace(block, transformed_block)


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