var filter = Fn.new { |target, greeting, is_super|
  var result = ""
  if (is_super) {
    result = "Super "
  }
  return result + greeting + " " + target
}
