a: [(x) -> x, (x) -> x * x]

puts a.length is 2


regex: /match/i
words: "I think there is a match in here."

puts !!words.match(regex)


neg: (3 -4)

puts neg is -1


func: ->
  return if true

puts func() is null


str: "\\"
reg: /\\/

puts reg(str) and str is '\\'


i: 10
while i -= 1

puts i is 0


money$: 'dollars'

puts money$ is 'dollars'