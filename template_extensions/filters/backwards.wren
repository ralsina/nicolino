var filter = Fn.new { |target|
    var y = ""
    for (c in (target.count-1)..0) {
        y = y + target[c]
    }
    return y
}
