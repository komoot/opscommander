#
# Deletes a stack.
#
def delete(ops, stack_name, input)
  # check if stack already exists
  existing_stack = ops.find_stack stack_name
  if existing_stack.nil? == false
    if input.choice("Delete stack with the name #{existing_stack.stack_name()}", "Yn") == 'y'
      existing_stack.delete
  end
  else
    puts "stack #{stack_name} does not exist"
    exit -1
  end
end