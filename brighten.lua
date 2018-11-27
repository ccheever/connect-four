function _brightenValue(x)
  local gap = 1 - x
  return 1 - (gap / 2)
end

function brighten(color)
  return {
    r = _brightenValue(color.r),
    g = _brightenValue(color.g),
    b = _brightenValue(color.b)
  }
end

return brighten
