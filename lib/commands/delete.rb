#
# Deletes a stack.
#
def delete(aws_connection, stack_name, input)
  ops = OpsWorks.new(aws_connection)
  # check if stack already exists
  existing_stack = ops.find_stack stack_name
  if existing_stack
    if input.choice("Delete stack with the name #{existing_stack.stack_name()}", "Yn") == 'y'
      existing_stack.delete
  end
  else
    puts "stack #{stack_name} does not exist"
    exit -1
  end
end