#
# Renames a stack.
#
def rename(aws_connection, old_name, new_name)
  ops = OpsWorks.new(aws_connection)

  stack  = ops.find_stack old_name
  if not stack
    puts "Stack #{old_name} does not exist"
    exit 1
  end

  stack.rename_to(new_name)
end
