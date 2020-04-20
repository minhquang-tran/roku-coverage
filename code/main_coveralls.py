import os
import re
import sys
from distutils.dir_util import copy_tree
from hashlib import md5
from subprocess import Popen, PIPE

if_regex = re.compile(r"(?<!\w)if(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
then_regex = re.compile(r"(?<!\w)then(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
else_regex = re.compile(r"(?<!\w)else(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
function_regex = re.compile(r"(?<!end |...\w)function(?= ?\()(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE)
end_function_regex = re.compile(r"(?<!\w)end function(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE)


def is_balanced(block):
    block = "\n".join(map(uncommented_line, block.split("\n")))
    if block.count("(") != block.count(")"):
        return False
    if block.count("{") != block.count("}"):
        return False
    if block.count("[") != block.count("]"):
        return False
    if len(function_regex.findall(block)) > len(end_function_regex.findall(block)) \
            and not block.strip().startswith("function"):
        return False
    return True


def uncommented_line(line):
    opened = False
    for pos in range(len(line)):
        char = line[pos]
        if char == '\"':
            opened = not opened
        if char == '\'' and not opened:
            return line[:pos]
    return line


def should_add_into_current_block(code_block):
    # CASES:
    #   Empty line & comments: handled by transforming function
    #   Imbalanced blocks
    #   After init() function until after next function
    #   Before last line of function until after next function: handled by transforming function
    if not is_balanced(code_block):
        return True

    code_block = code_block.lower()

    block_last_line = code_block.split("\n")[-1]
    if "sub init()" in code_block:
        if block_last_line.strip() == "sub init()":
            return True
        if block_last_line.strip().startswith(("sub ", "function ")):
            return False
        return True

    uncommented = uncommented_line(block_last_line)
    if if_regex.findall(uncommented) or else_regex.findall(uncommented):
        then_split = then_regex.split(uncommented)
        if len(then_split) > 1 and then_split[-1]:
            return False
        return True

    if else_regex.findall(block_last_line):
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
    block = block.lower()
    words = block.replace("\n", " ").strip().split(" ")

    # if words[0] not in ["if", "else"]:
    first_line = uncommented_line(block.split("\n", 1)[0])
    if not if_regex.findall(first_line) and not else_regex.findall(first_line):
        return 0  # Normal block of code

    if first_line.strip().startswith("if "):
        then_split = then_regex.split(block, 1)
        print("then_split", then_split)
        if len(then_split) > 1 and then_split[1].split("\n")[0].strip():
            if else_regex.findall(then_split[1]):
                return 0
            return 1  # Inline if then (else)

    # if first_line.split(" ").count("if") == 1 and first_line.split(" ").count("then") == 1:
    #     then_split = first_line.strip().split(" then")
    #     if then_split[1] and not then_split[1].strip().startswith("'"):
    #         return 1  # Inline if

    return 2  # Normal if/else


def get_line_count(block):
    return block.count("\n") + 1


coverage_line_template = "{}_markTestCoverage({})"


# def transform_inline_if(component_name, block, line_num):
#     line_count = get_line_count(block)
#     coverage_line = coverage_line_template.format(component_name, list(range(line_num, line_num + line_count)))
#
#     then_split = then_regex.split(block)
#     return "\n".join([then_split[0],
#                       coverage_line,
#                       then_split[1],
#                       (len(block) - len(block.lstrip(' '))) * " " + "end if"]), \
#            [line_num + extra_line for extra_line in range(line_count)]


def transform_block(component_name, block, line_num):
    print(">>>\n", block, "\n<<<")
    if not block.strip() or block.strip().lower().startswith(("'", "end ", "sub ", "function ")):
        return block, []
    block_type = get_block_type(block)
    print("TYPE", block_type)
    line_count = get_line_count(block)
    coverage_line = coverage_line_template.format(component_name, list(range(line_num, line_num + line_count)))
    if block_type == 0:
        return \
            coverage_line + "\n" + block, \
            [line_num + extra_line for extra_line in range(line_count)]
    if block_type == 1:
        then_split = then_regex.split(block)
        return "\n".join([then_split[0],
                          coverage_line,
                          then_split[1],
                          "end if"]), \
               [line_num + extra_line for extra_line in range(line_count)]

    line_split = block.split("\n", 1)
    # print("line_split", line_split)
    line_split[0] += "\n" + coverage_line_template.format(component_name, [line_num])
    block_covered_lines = [line_num]
    line_split[1], covered_lines = transform_block(component_name, line_split[1], line_num + 1)
    block_covered_lines += covered_lines
    return "\n".join(line_split), block_covered_lines


mark_test_function_template = """sub {0}_markTestCoverage(indices)
  for each i in indices
    index = (startingIndex + i).toStr()
    m.global.testCoverage.{0}[index] += 1
  end for
end sub
"""


def transform_component(component_file):
    global coverage_dir
    local_file_path = component_file.replace(coverage_dir, "")
    component_raw = open(component_file, 'r').read()
    # component_name = component_file.split(os.sep)[-1].split(".")[0].replace("-", "_")
    component_name = "_".join(filter(len, local_file_path.split(".")[0].split(os.sep))).replace("-", "_")

    hashed = md5(component_raw.encode('utf-8')).hexdigest()
    print("------------------------\nTransforming component: " + local_file_path)

    line_num = 1
    transformed_blocks = []
    component_covered_lines = []
    for block in to_code_blocks(component_raw):
        transformed_block, covered_lines = transform_block(component_name, block, line_num)
        transformed_blocks.append(transformed_block)
        component_covered_lines += covered_lines
        line_num += block.count("\n") + 1

    mark_test_function = mark_test_function_template.format(component_name)

    with open(component_file, 'w') as file_object:
        file_object.write("\n".join([mark_test_function] + transformed_blocks))

    return component_name, local_file_path, line_num - 1, component_covered_lines, hashed


main_init_mark = "' <Test Coverage: add new global fields here> '"
main_report_mark = "' <Test Coverage: print report here> '"

main_coverage_lines = """
  m.global.addFields({testCoverage: createObject("roSGNode", "ContentNode")})
  testCoverageComponents = []"""

main_component_lines = """
  testCoverageComponents.push("{0}")
  m.global.testCoverage.addFields({{{0}: createObject("roSGNode","ContentNode")}})
  m.global.testCoverage.{0}.addFields({{
    "path": "{1}"
    "length": {2}
    "hash": "{4}"
  }})
  lines = {{}}
  for each line in {3}
    lines[line.toStr()] = 0    
  end for
  m.global.testCoverage.{0}.addFields(lines)"""

report_coverage_lines = """
    sourceFilesAA = []
    for each componentName in testCoverageComponents
      componentCoverage = m.global.testCoverage[componentName]
      coverage = []
      for i = 1 to componentCoverage.length
        coverage.push(componentCoverage[i.toStr()])
      end for
      sourceFilesAA.push({{
        "name": componentCoverage.path
        "source_digest": componentCoverage.hash
        "coverage": coverage
      }})
    end for
    coverageJsonRaw = {{
      "service_job_id": "{}"
      "service_name": "circle-ci"
      "source_files": sourceFilesAA
    }}

    coverallsRequest = CreateObject("roUrlTransfer")
    coverallsRequest.setUrl("https://coveralls.io/api/v1/jobs")
    coverallsRequest.AsyncPostFromString("json=" + formatJson(coverageJsonRaw))"""


def transform_main(main_file, components):
    component_lines = []
    for component, file_path, line_count, covered_lines, hashed in components:
        if covered_lines:
            component_lines.append(main_component_lines.format(component, file_path, line_count, covered_lines, hashed))
    if not component_lines:
        return
    main_raw = open(main_file, 'r').read()
    main_raw = main_raw.replace(main_init_mark, "\n".join([main_coverage_lines] + component_lines))
    main_raw = main_raw.replace(main_report_mark, report_coverage_lines.format(sys.argv[2]))
    with open(main_file, 'w') as file_object:
        file_object.write(main_raw)


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

# transforming component files
components = []
for component_file in component_files:
    components.append(transform_component(component_file))

# transforming main.brs file
transform_main(main_file, components)

print("DONE")

# os.environ["ROKU_DEV_TARGET"] = "192.168.2.2"
# os.environ["DEVPASSWORD"] = "aaaa"
# sp = Popen(["make", "install"], cwd=coverage_dir, stdin=PIPE)
# sp.stdin.write(b'\n')
# sp.wait()
