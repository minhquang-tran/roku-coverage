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

  # DO STUFF INSTEAD OF THE LINE!!
  return "\n".join(out_blocks), end_index

def transform_component(comp_name):
  txt = open(comp_name, 'r').read()

  if "sub init()" not in txt:
    # No init() function
    return None

  lines = txt.split("\n")

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

  line_num = 0
  for function in functions:
    if function.startswith("sub init()"):
      init_func = function
    else:
      out, line_num = transform_func(comp_name, function, line_num)
      txt = txt.replace(function, out)

  comp_init = COVERAGE_INIT.format(comp_name, line_num)
  insert_index = init_func.index("\n")
  init_out = init_func[:insert_index] + comp_init + init_func[insert_index:]
  txt = txt.replace(init_func, init_out)

  return txt

# MAIN
# comp_name = "input.brs"
# output = transform_component(comp_name)

# out_file = open("output.brs", "w")
# out_file.write(output)
# out_file.close()

# print("Done!")

import sys, os
input_path = sys.argv[1]
# print("input path: ", input_path)
output_path = input_path + "-coverage"
# print("output path :", output_path, os.path.exists(output_path))
if not os.path.exists(output_path):
    os.mkdir(output_path)


from distutils.dir_util import copy_tree

# copy subdirectory example
fromDirectory = input_path
toDirectory = output_path

copy_tree(fromDirectory, toDirectory)