import os
import re
import sys
from distutils.dir_util import copy_tree
from hashlib import md5
from subprocess import Popen, PIPE

# if_regex = re.compile(r"(?<!end |...\w)if(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
then_regex = re.compile(r"(?<!\w)then(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
else_regex = re.compile(r"(?<!\w)else(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE | re.MULTILINE)
function_regex = re.compile(r"(?<!end |...\w)function(?= ?\()(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE)
end_function_regex = re.compile(r"(?<!\w)end function(?!\w)(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", flags=re.IGNORECASE)


def is_balanced(block):
    if type(block) is list:
        uncommented = "\n".join(map(uncommented_line, block))
    else:
        uncommented = "\n".join(map(uncommented_line, block.split("\n")))
    if uncommented.count("(") != uncommented.count(")"):
        return False
    if uncommented.count("{") != uncommented.count("}"):
        return False
    if uncommented.count("[") != uncommented.count("]"):
        return False
    if len(function_regex.findall(uncommented)) > len(end_function_regex.findall(uncommented)) \
            and not uncommented.strip().startswith("function"):
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


def to_code_blocks(lines):
    if type(lines) is not list:
        lines = lines.split("\n")
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
    # block = block.lower()

    block = "\n".join(map(uncommented_line, block.split("\n"))).lower().strip()
    if not block.startswith(("if ", "for ", "else if ")) and block != "else":
        return 0  # Normal block of code

    if block.strip().startswith("if "):
        then_split = then_regex.split(block, 1)
        # print("then_split", then_split)
        if len(then_split) > 1 and then_split[1].split("\n")[0].strip():
            if else_regex.findall(then_split[1]):
                return 0  # Inline if then
            return 1  # Inline if then else

    return 2  # Normal if/else


def get_line_count(block):
    return block.count("\n") + 1


def get_function_ranges(block):
    captured_blocks = []
    function_start_index = -1

    processing_block = []
    capturing = False
    lines = block.split("\n")
    for index in range(len(lines)):
        line = lines[index]
        uncommented = uncommented_line(line)
        if end_function_regex.findall(uncommented) and is_balanced(processing_block):
            captured_blocks.append((function_start_index, index))
            capturing = False
        if function_regex.findall(uncommented) and not capturing:
            processing_block = []
            function_start_index = index + 1
            capturing = True
            continue
        if capturing:
            processing_block.append(line)

    return captured_blocks


def process_anonymous_functions(component_name, block, starting_line):
    lines = block.split("\n")
    local_covered_lines = list(range(starting_line, starting_line + get_line_count(block)))
    captured_blocks = get_function_ranges(block)

    if not captured_blocks:
        return block, local_covered_lines, local_covered_lines

    block_covered_lines = local_covered_lines

    for start_index, end_index in reversed(captured_blocks):
        function_line_range = range(starting_line + start_index, starting_line + end_index)
        local_covered_lines = [line_num for line_num in local_covered_lines if line_num not in function_line_range]
        function_lines = lines[start_index:end_index]
        transformed_blocks, function_covered_lines, _\
            = transform_lines(component_name, function_lines, function_line_range[0])
        block_covered_lines = sorted(local_covered_lines + function_covered_lines)
        lines = lines[:start_index] + transformed_blocks + lines[end_index:]

    return "\n".join(lines), local_covered_lines, block_covered_lines


coverage_line_template = "{}_markTestCoverage({})"


def transform_block(component_name, block, line_num):
    # print(">>>\n", block, "\n<<<")
    if not block.strip() or block.strip().lower().startswith(("'", "end ", "sub ", "function ")):
        return block, []
    block_type = get_block_type(block)
    # print("TYPE", block_type)
    if block_type == 0:
        block, local_covered_lines, block_covered_lines = process_anonymous_functions(component_name, block, line_num)
        coverage_line = coverage_line_template.format(component_name, local_covered_lines)
        return \
            coverage_line + "\n" + block, \
            block_covered_lines
    if block_type == 1:
        then_split = then_regex.split(block)
        processed_statements, local_covered_lines, block_covered_lines \
            = process_anonymous_functions(component_name, then_split[1], line_num)
        coverage_line = coverage_line_template.format(component_name, local_covered_lines)
        return "\n".join([then_split[0],
                          coverage_line,
                          processed_statements,
                          "end if"]), \
               block_covered_lines

    covered_lines = list(range(line_num, line_num + get_line_count(block)))
    coverage_line = coverage_line_template.format(component_name, covered_lines)
    return block + "\n" + coverage_line, covered_lines


mark_test_function_template = """sub {0}_markTestCoverage(indices)
  for each i in indices
    m.global.testCoverage.{0}[i.toStr()] += 1
  end for
end sub
"""


def transform_lines(component_name, code_raw, starting_line_num):
    line_num = starting_line_num
    transformed_blocks = []
    component_covered_lines = []
    for block in to_code_blocks(code_raw):
        transformed_block, covered_lines = transform_block(component_name, block, line_num)
        transformed_blocks.append(transformed_block)
        component_covered_lines += covered_lines
        line_num += get_line_count(block)
    return transformed_blocks, component_covered_lines, line_num


def transform_component(component_file, coverage_dir):
    local_file_path = component_file.replace(coverage_dir, "")
    component_raw = open(component_file, 'r').read()
    # component_name = component_file.split(os.sep)[-1].split(".")[0].replace("-", "_")
    component_name = "_".join(filter(len, local_file_path.split(".")[0].split(os.sep))).replace("-", "_")

    hashed = md5(component_raw.encode('utf-8')).hexdigest()
    print("------------------------\nTransforming component: " + local_file_path)

    transformed_blocks, component_covered_lines, line_num = transform_lines(component_name, component_raw, 1)
    mark_test_function = mark_test_function_template.format(component_name)

    with open(component_file, 'w') as file_object:
        file_object.write("\n".join([mark_test_function] + transformed_blocks))
    # print(component_name, component_covered_lines)
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
      "repo_token": "{}"
      "source_files": sourceFilesAA
    }}
    
    coverallsRequest = CreateObject("roUrlTransfer")
    coverallsRequest.AddHeader("X-Roku-Reserved-Dev-Id", "")
    coverallsRequest.setCertificatesFile("common:/certs/ca-bundle.crt")
    coverallsRequest.initClientCertificates()
    coverallsRequest.setUrl("https://coveralls.io/api/v1/jobs")    
   
    result = coverallsRequest.postFromString("json=" + formatJson(coverageJsonRaw))
    ?">>Coveralls result:", result"""


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
    if "tests" in root or "tasks" in root or "app" in root:  # TODO: check for tasks
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
    components.append(transform_component(component_file, coverage_dir))

# transforming main.brs file
transform_main(main_file, components)

print("DONE")

os.environ["ROKU_DEV_TARGET"] = "192.168.2.2"
os.environ["DEVPASSWORD"] = "aaaa"
sp = Popen(["make", "install"], cwd=coverage_dir, stdin=PIPE)
sp.stdin.write(b'\n')
sp.wait()
