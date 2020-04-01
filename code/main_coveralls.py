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
        if block_last_line.strip().startswith(("sub ", "function ")):
            return False
        return True

    if block_last_line.strip().split(" ")[0] in ("else", "if"):
        if "then" in block_last_line.split(" ") and not block_last_line.strip().endswith(" then"):
            return False
        return True

    if "else" in block_last_line.split(" "):
        return True
    return False


def to_code_blocks(brs_text):
    lines = brs_text.split("\n")
    blocks = []
    for line in lines:
        if not blocks:
            blocks.append(line)
            continue
        if should_add_into_current_block(blocks[-1]):
            blocks[-1] += "\n" + line
        else:
            blocks.append(line)
    return blocks


def get_block_type(block):
    words = block.replace("\n", " ").split(" ")
    if "if" not in words and "else" not in words:
        return 0  # Normal block of code

    first_line = block.split("\n", 1)[0]
    if first_line.split(" ").count("if") == 1 and first_line.split(" ").count("then") == 1 \
            and not first_line.strip().endswith(" then"):
        return 1  # Inline if

    return 2  # Normal if/else


def get_line_count(block):
    return block.count("\n") + 1


extra_sub_template = """
sub {}_markLine{}()
  {}_markTestCoverage({}, {})
  {}
end sub"""

extra_function_template = """
function {}_markLine{}() as object
  {}_markTestCoverage({}, {})
  return {}
end function"""


def transform_inline_if(component_name, block, line_num):
    if " then return " in block:
        then_split = block.split("then return ")
        line_count = get_line_count(then_split[1])
        extra_function = extra_function_template.format(component_name, line_num,
                                                        component_name, line_num, line_count,
                                                        then_split[1])
        then_split[1] = "{}_markLine{}()".format(component_name, line_num)
        return \
            "then return ".join(then_split), \
            extra_function, \
            [line_num + extra_line for extra_line in range(line_count)]

    then_split = block.split("then ")
    line_count = get_line_count(then_split[1])
    extra_function = extra_sub_template.format(component_name, line_num,
                                               component_name, line_num, line_count,
                                               then_split[1])
    then_split[1] = "{}_markLine{}()".format(component_name, line_num)
    return "then ".join(then_split), extra_function, [line_num + extra_line for extra_line in range(line_count)]


coverage_line_template = "{}_markTestCoverage({}, {})"


def transform_block(component_name, block, line_num):
    if not block.strip() or block.strip().startswith(("'", "end ", "sub ", "function ")):
        return block, [], []
    block_type = get_block_type(block)
    if block_type == 0:
        line_count = get_line_count(block)
        return \
            coverage_line_template.format(component_name, line_num, line_count) + "\n" + block, \
            [], \
            [line_num + extra_line for extra_line in range(line_count)]
    if block_type == 1:
        return transform_inline_if(component_name, block, line_num)

    line_split = block.split("\n", 1)
    line_split[0] += "\n" + coverage_line_template.format(component_name, line_num, 1)
    block_covered_lines = [line_num]
    line_split[1], extra_block, covered_lines = transform_block(component_name, line_split[1], line_num + 1)
    block_covered_lines += covered_lines
    return "\n".join(line_split), extra_block, block_covered_lines


mark_test_function_template = """sub {0}_markTestCoverage(startingIndex, lineCount)
  for i = 0 to line_num - 1
    index = (startingIndex + lineCount).toStr()
    m.global.testCoverage.{0}.[index] += 1
  end for
end sub
"""


def transform_component(component_file):
    component_raw = open(component_file, 'r').read()
    component_name = component_file.split(os.sep)[-1].split(".")[0].replace("-", "_")
    print("\nCOMPONENT: " + component_name)

    line_num = 1
    transformed_blocks = []
    extra_blocks = []
    component_covered_lines = []
    # for line in to_code_blocks(component_raw):
    #     print(">>>\n", line, "\n<<<")
    for block in to_code_blocks(component_raw):
        transformed_block, extra_block, covered_lines = transform_block(component_name, block, line_num)
        transformed_blocks.append(transformed_block)
        if extra_block:
            extra_blocks.append(extra_block)
        # print("covering", len(component_covered_lines), len(covered_lines))
        # print(component_covered_lines)
        component_covered_lines += covered_lines
        line_num += block.count("\n") + 1

    mark_test_function = mark_test_function_template.format(component_name)

    print("\n".join([mark_test_function] + transformed_blocks + extra_blocks))
    with open(component_file, 'w') as file_object:
        file_object.write("\n".join([mark_test_function] + transformed_blocks + extra_blocks))

    print(component_covered_lines)
    print("File length:", line_num - 1)

    return component_name, line_num - 1, component_covered_lines


main_component_lines = """
  m.global.testCoverage.addFields({{{0}: createObject("roSGNode","ContentNode")}})
  m.global.testCoverage.{0}.addFields({{"length":{1}}})
  lines = {{}}
  for each line in {2}
    lines[line.toStr()] = 0    
  end for
  m.global.testCoverage.{0}.addFields(lines)"""


def transform_main(main_file, components):
    component_lines = []
    for component, line_count, covered_lines in components:
        component_lines.append(main_component_lines.format(component, line_count, covered_lines))
    print("\n".join(component_lines))


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
    components.append(transform_component(component_file))

print(components)
transform_main(main_file, components)
