COVERAGE_INIT = "\nm.global.testCoverage[\"{}\"] = CreateObject(\"roArray\", {}, false)"
COVERAGE_LINE = "m.global.testCoverage[\"{}\"][{}] = true"

MAIN_COVERAGE_LINES = r"""m.global.addFields({
    testCoverage: {}
    testCoverageReport: {}
  })"""

REPORT_COVERAGE_LINES = r"""    for component in m.global.testCoverage
        uncoveredLines = []
        linesCount = component.count()
        for i in linesCount
            if component[i] <> true
                uncoveredLines.pop(i)
            end if
        end for
        coveredCount = linesCount - uncoveredLines.count()
        coveragePercent = (coveredCount / linesCount * 100).toStr()
        ?"================================================================="
        ?substitute("===   Component {} Test Suite:", component)
        ?"==="
        ?substitute("===   Total  = {} ; Covered  =  {} ; Uncovered   =  {} ; Coverage: {}%", linesCount, coveredCount, uncoveredLines.count(), coveragePercent)
        ?"================================================================="
    end for"""

def is_balanced(block):
    if block.count("(") != block.count(")"):
        return False
    if block.count("{") != block.count("}"):
        return False
    if block.count("[") != block.count("]"):
        return False
    return True

def to_function_list(brs_text):
    lines = brs_text.split("\n")

    functions = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("sub") or lines[i].startswith("function"):
            function = [lines[i]]
            j = i + 1
            while not (lines[j].endswith("end sub") or lines[j].endswith("end function")):
                function.append(lines[j])
                j += 1

            function.append(lines[j])
            functions.append("\n".join(function))
            i = j

        i += 1
    return functions

def transform_func(comp_name, function, start_index):
    lines = function.split("\n")
    blocks = []
    i = 0
    while i < len(lines):
        block = lines[i]
        if not lines[i].strip() or lines[i].strip().startswith(("'","end")):
            blocks[-1] += "\n" + block
            i += 1
            continue

        j = i + 1
        while not is_balanced(block):
            block += "\n" + lines[j]
            j += 1

        i = j
        blocks.append(block)

    blocks_count = len(blocks)
    end_index = start_index + blocks_count - 1

    insert_lines = [COVERAGE_LINE.format(comp_name, i) for i in range(start_index, end_index)]

    out_blocks = [None] * (blocks_count * 2 - 1)
    out_blocks[::2] = blocks
    out_blocks[1::2] = insert_lines

    return "\n".join(out_blocks), end_index

def transform_component(component):
    component_name, component_files = component
    component_files.sort()
    print("------------------------\nTransforming component: " + component_name)

    component_texts = list(map(lambda f: open(f, 'r').read(), component_files))
    if not any("sub init()" in txt for txt in component_texts):
        # No init() function
        print("WARNING: No init() function found.")
        return None

    line_num = 0
    init_function = None
    component_main_index = None
    for i in range(len(component_texts)):
        component_text = component_texts[i]
        function_list = to_function_list(component_text)
        for function in function_list:
            if function.startswith("sub init()"):
                init_function = function
                component_main_index = i
            else:
                transformed_function, line_num = transform_func(component_name, function, line_num)
                component_text = component_text.replace(function, transformed_function)
        component_texts[i] = component_text

    coverage_init = COVERAGE_INIT.format(component_name, line_num)
    insert_index = init_function.index("\n")
    init_out = init_function[:insert_index] + coverage_init + init_function[insert_index:]
    component_texts[component_main_index] = component_texts[component_main_index].replace(init_function, init_out)

    for component_file, component_text in zip(component_files, component_texts):
        print("Component file: " + component_file)
        with open(component_file, 'w') as file_object:
            file_object.write(component_text)

def transform_main(main_file):
    main_text = open(main_file, 'r').read()
    main_text = main_text.replace("' <Test Coverage: add new global fields here> '", MAIN_COVERAGE_LINES)
    main_text = main_text.replace("' <Test Coverage: print report here> '", REPORT_COVERAGE_LINES)
    with open(main_file, 'w') as file_object:
            file_object.write(main_text)


# read input & create directory
import sys, os
# project_dir = sys.argv[1]
project_dir = "./lofi-protoman"
if not os.path.exists(project_dir):
    print("Project not found")
    sys.exit()

coverage_dir = project_dir + "-coverage"
if not os.path.exists(coverage_dir):
    os.mkdir(coverage_dir)

# copy files from directory
from distutils.dir_util import copy_tree
copy_tree(project_dir, coverage_dir)

#get list of copied files
# components_dir = os.path.join(coverage_dir, "components")
component_files = []
main_file = None
for root, dirs, files in os.walk(coverage_dir):
    if "tests" in root:
        continue
    for name in files:
        if "source" in root and name == "main.brs":
            main_file = os.path.join(root, name)
        elif "components" in root and name.endswith(".brs"):
            component_files.append(os.path.join(root, name))
component_files.sort()

from itertools import groupby

components = [(key, list(group)) for key, group in groupby(component_files, lambda f: f.split("/")[4].split(".")[0])]

for c in components:
    # print(c)
    transform_component(c)
transform_main(main_file)