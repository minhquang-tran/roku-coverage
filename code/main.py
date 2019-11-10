COVERAGE_INIT = "\nm.global.testCoverage[\"{}\"] = CreateObject(\"roArray\", {}, false)"
COVERAGE_LINE = "m.global.testCoverage[\"{}\"][{}] = true"

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
    print("Component: " + component_name)

    component_texts = list(map(lambda f: open(f, 'r').read(), component_files))
    if not any("sub init()" in txt for txt in component_texts):
        # No init() function
        return None

    # print(component_files)

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

    # f = open(comp_file, 'r')
    # txt = f.read()
    # comp_name = os.path.basename(comp_file)
    # if "sub init()" not in txt:
    #     # No init() function
    #     return None

    # lines = txt.split("\n")

    # functions = []
    # i = 0
    # while i < len(lines):
    #     if lines[i].startswith("sub") or lines[i].startswith("function"):
    #         function = [lines[i]]
    #         j = i + 1
    #         while not (lines[j].endswith("end sub") or lines[j].endswith("end function")):
    #             function.append(lines[j])
    #             j += 1

    #         function.append(lines[j])
    #         functions.append("\n".join(function))
    #         i = j

    #     i += 1

    # line_num = 0
    # for function in functions:
    #     if function.startswith("sub init()"):
    #         init_func = function
    #     else:
    #         out, line_num = transform_func(comp_name, function, line_num)
    #         txt = txt.replace(function, out)

    # comp_init = COVERAGE_INIT.format(comp_name, line_num)
    # insert_index = init_func.index("\n")
    # init_out = init_func[:insert_index] + comp_init + init_func[insert_index:]
    # txt = txt.replace(init_func, init_out)

    # return txt

# SAMPLE USES
# comp_name = "input.brs"
# output = transform_component(comp_name)

# out_file = open("output.brs", "w")
# out_file.write(output)
# out_file.close()

# print("Done!")

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
components_dir = os.path.join(coverage_dir, "components")
component_files = []
main_file = None
for root, dirs, files in os.walk(components_dir):
    if "test" in root:
        continue
    for name in files:
        if name == "main.brs":
            main_file = os.path.join(root, name)
        elif name.endswith(".brs"):
            component_files.append(os.path.join(root, name))


# for component in component_files:
#     print(component)
    # output = transform_component(component)
    # if not output:
    #     continue
    # out_file = open(component, "w")
    # out_file.write(output)
    # out_file.close()

from itertools import groupby

# for key, comp in groupby(component_files, lambda f: f.split("/")[4].split(".")[0]):
#     print(key, list(comp))
components = [(key, list(group)) for key, group in groupby(component_files, lambda f: f.split("/")[4].split(".")[0])]

for c in components:
    # print(c)
    transform_component(c)