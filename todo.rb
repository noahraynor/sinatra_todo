require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Create new list
get "/lists/new" do
  erb :new_list, layout: :layout
end

# View one list
get "/lists/:list_num" do
  @list_num = params[:list_num].to_i
  @list = session[:lists][get_list_index(@list_num)]
  erb :list, layout: :layout
end

# Edit one list
get "/lists/:list_num/edit" do
  @list_num = params[:list_num].to_i
  erb :edit_list, layout: :layout
end

# Update one list
post "/lists/:list_num" do
  @list_num = params[:list_num].to_i
  list_name = params[:list_name].strip
  old_name = session[:lists][get_list_index(@list_num)][:name]

  error = error_for_list_name(list_name, old_name)
  if error
    session[:failure] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][get_list_index(@list_num)][:name] = list_name
    session[:success] = "The list name has been edited."
    redirect "/lists/#{@list_num}"
  end
end

# remove a list
post "/lists/:list_num/delete" do
  list_num = params[:list_num].to_i
  old_name = session[:lists][get_list_index(list_num)][:name]
  session[:lists].delete_at(get_list_index(list_num))
  session[:success] = "The list '#{old_name}' has been deleted."
  redirect "/lists"
end

# Add the new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:failure] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: [], num: next_list_num}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Add todo
post "/lists/:list_num/addtodo" do
  @list_num = params[:list_num].to_i
  @list = session[:lists][get_list_index(@list_num)]
  todo_name = params[:todo_name].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:failure] = error
    erb :list, layout: :layout
  else
    id = next_todo_num(@list_num)
    session[:lists][get_list_index(@list_num)][:todos] << {name: todo_name, complete: false, num: id}
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_num}"
  end
end

# Remove todo
post "/lists/:list_num/:todo_num/delete" do
  todo_num = params[:todo_num].to_i
  @list_num = params[:list_num].to_i
  todos = session[:lists][get_list_index(@list_num)][:todos]


  todos.each do |todo|
    session[:lists][get_list_index(@list_num)][:todos].delete(todo) if todo[:num] == todo_num
  end

  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_num}"
end

# update status of a todo
post "/lists/:list_num/:todo_num/complete" do
  todo_num = params[:todo_num].to_i
  @list_num = params[:list_num].to_i
  todos = session[:lists][get_list_index(@list_num)][:todos]

  todos.each do |todo|
    todo[:complete] = true if todo[:num] == todo_num && params[:completed] == "true"
    todo[:complete] = false if todo[:num] == todo_num && params[:completed] == "false"
  end

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_num}"
end

post "/lists/:list_num/all" do
  @list_num = params[:list_num].to_i
  todos = session[:lists][get_list_index(@list_num)][:todos]

  todos.each do |todo|
    todo[:complete] = true
  end

  session[:success] = "All lists have been marked completed."
  redirect "/lists/#{@list_num}"
end

# check for list errors
def error_for_list_name(list_name, old_name = nil)
  return nil if list_name == old_name
  if list_name.size <= 0 || list_name.size > 100
      "Error. List name must be from 1 to 100 characters."
  elsif session[:lists].any? { |list| list[:name] == list_name }
      "Error. List name already used."
  else
      nil
  end
end

# check for todo errors
def error_for_todo_name(todo_name)
  if todo_name.size <= 0 || todo_name.size > 100
    "Error. Todo name must be from 1 to 100 characters."
  else
    nil
  end
end

def next_todo_num(list_num)
  todo = session[:lists][get_list_index(list_num)][:todos].max {|a,b| a[:num] <=> b[:num]}
  todo ? todo[:num] + 1 : 0
end

def next_list_num
  list = session[:lists].max {|a,b| a[:num] <=> b[:num]}
  list ? list[:num] + 1 : 0
end

def todo_ratio(list)
  total_todos = list[:todos].size
  uncompleted_todos = list[:todos].count {|todo| !todo[:complete]}
  [uncompleted_todos, total_todos]
end

def list_complete(list)
  return "complete" if list[:todos].all? {|todo| todo[:complete]} && list[:todos].size > 0
  ""
end

def sort_lists(lists)
  lists.sort_by do |list|
    list_complete(list) == "complete" ? 1 : 0
  end
end

def get_list_index(list_num)
  session[:lists].find_index {|list| list[:num] == list_num}
end