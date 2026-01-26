
-- Add the binding directory to package.cpath
package.cpath = package.cpath .. ";../?.so"

local mp = require("multipart_parser")

return require("tap")(function(test)
  local parse = mp.parse

  local deepEqual = require("deep-equal")
  local pp = assert(require("pretty-print"))
  local p = pp.prettyPrint

  local suites = {
    ["Content-type: multipart/form-data, boundary=AaB03x"] = [[
--AaB03x
content-disposition: form-data; name="field1"

Joe Blow
--AaB03x
content-disposition: form-data; name="pics"
Content-type: multipart/mixed, boundary=BbC04y

--BbC04y
Content-disposition: attachment; filename="file1.txt"
Content-Type: text/plain

... contents of file1.txt ...
--BbC04y
Content-disposition: attachment; filename="file2.gif"
Content-type: image/gif
Content-Transfer-Encoding: binary

...contents of file2.gif...
--BbC04y--
--AaB03x--
]],
    ["Content-type: multipart/form-data, boundary=AaB03y"] = [[
--AaB03y
content-disposition: form-data; name="field1"

Joe Blow
--AaB03y
content-disposition: form-data; name="pics"; filename="file1.txt"
Content-Type: text/plain

 ... contents of file1.txt ...
--AaB03y--
]],
    ["Content-type: multipart/form-data, boundary=AaB03z"] = [[
--AaB03z
content-disposition: form-data; name="field1"
content-type: text/plain; charset=windows-1250
content-transfer-encoding: quoted-printable


Joe owes =80100.
--AaB03z--]],
    ["multipart/form-data; boundary=----WebKitFormBoundary6bHnnUFIFpNjRCNi"] = [[
------WebKitFormBoundary6bHnnUFIFpNjRCNi
Content-Disposition: form-data; name="field1"


------WebKitFormBoundary6bHnnUFIFpNjRCNi
Content-Disposition: form-data; name="file"; filename=""
Content-Type: application/octet-stream


------WebKitFormBoundary6bHnnUFIFpNjRCNi--
]],
  }

  local results = {
    ["Content-type: multipart/form-data, boundary=AaB03y"] = {
      pics = {
        " ... contents of file1.txt ...",
        filename = "file1.txt",
        ["Content-Type"] = "text/plain",
      },
      field1 = "Joe Blow",
    },

    ["multipart/form-data; boundary=----WebKitFormBoundary6bHnnUFIFpNjRCNi"] = {
      file = {
        "",
        filename = "",
        ["Content-Type"] = "application/octet-stream",
      },
      field1 = "",
    },

    ["Content-type: multipart/form-data, boundary=AaB03x"] = {
      pics = {
        { '... contents of file1.txt ...', filename = 'file1.txt', ['Content-Type'] = 'text/plain' },
        { '...contents of file2.gif...', filename = 'file2.gif', ['Content-type'] = 'image/gif', ['Content-Transfer-Encoding'] = 'binary' }
      },
      field1 = 'Joe Blow'
    },

    ["Content-type: multipart/form-data, boundary=AaB03z"] = {
      field1 = "\nJoe owes =80100.",
    },
  }

  for k, v in pairs(suites) do
    test(k, function()
      local ret = parse(v, k)
      assert(deepEqual(results[k], ret), pp.dump({ expected = results[k], got = ret }))
    end)
  end

  test("simple field", function()
    local body = [[
--A
Content-Disposition: form-data; name="foo"

bar
--A--
]]
    local expected = { foo = "bar" }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=A")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("empty body", function()
    local body = ""
    local expected = {}
    local ret = parse(body, "Content-type: multipart/form-data, boundary=EMPTY")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("missing boundary param", function()
    local body = [[
--B
Content-Disposition: form-data; name="foo"

bar
--B--
]]
    local expected = { foo = "bar" }
    local ret = parse(body, "multipart/form-data; boundary=B")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("repeated field", function()
    local body = [[
--R
Content-Disposition: form-data; name="foo"

one
--R
Content-Disposition: form-data; name="foo"

two
--R--
]]
    local expected = { foo = { "one", "two" } }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=R")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("illegal header", function()
    local body = [[
--BAD
Content-Disposition form-data; name="foo"

bar
--BAD--
]]
    local expected = {}
    local ret = parse(body, "Content-type: multipart/form-data, boundary=BAD")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("missing end boundary", function()
    local body = [[
--END
Content-Disposition: form-data; name="foo"

bar
]]
    local expected = { foo = "bar" }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=END")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("only boundary, no parts", function()
    local body = "--ONLY--\r\n"
    local expected = {}
    local ret = parse(body, "Content-type: multipart/form-data, boundary=ONLY")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("content contains boundary-like string", function()
    local body = [[
--B
Content-Disposition: form-data; name="foo"

this is not a boundary: --B
--B--
]]
    local expected = { foo = "this is not a boundary: --B" }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=B")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("multiple files (nested multipart)", function()
    local body = [[
--MultiFile
Content-Disposition: form-data; name="desc"
Content-Type: text/plain

多个文件上传
--MultiFile
Content-Disposition: form-data; name="files"
Content-Type: multipart/mixed; boundary=InnerBoundary

--InnerBoundary
Content-Disposition: attachment; filename="a.txt"
Content-Type: text/plain

A内容
--InnerBoundary
Content-Disposition: attachment; filename="b.txt"
Content-Type: text/plain

B内容
--InnerBoundary--
--MultiFile--
]]
    local expected = {
      desc = "多个文件上传",
      files = {
        { "A内容", filename = "a.txt", ["Content-Type"] = "text/plain" },
        { "B内容", filename = "b.txt", ["Content-Type"] = "text/plain" },
      },
    }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=MultiFile")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("no name part", function()
    local body = [[
--NoName
Content-Disposition: form-data; name="foo"
Content-Type: text/plain

bar
--NoName
Content-Disposition: attachment; filename="x.png"
Content-Type: image/png

PNGDATA
--NoName--
]]
    local expected = {
      foo = "bar",
      [1] = { "PNGDATA", filename = "x.png", ["Content-Type"] = "image/png" },
    }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=NoName")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("empty part", function()
    local body = [[
--EmptyPart
Content-Disposition: form-data; name="empty"
Content-Type: text/plain

--EmptyPart--
]]
    local expected = { empty = "" }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=EmptyPart")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("CRLF strict multipart", function()
    local body = table.concat({
      "--CRLFBOUNDARY\r\n",
      'Content-Disposition: form-data; name="alpha"\r\n',
      "Content-Type: text/plain\r\n",
      "\r\n",
      "foo\r\n",
      "--CRLFBOUNDARY\r\n",
      'Content-Disposition: form-data; name="beta"; filename="b.txt"\r\n',
      "Content-Type: text/plain\r\n",
      "\r\n",
      "bar\r\n",
      "--CRLFBOUNDARY--\r\n",
    })
    local expected = {
      alpha = "foo\r\n",
      beta = { "bar\r\n", filename = "b.txt", ["Content-Type"] = "text/plain" },
    }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=CRLFBOUNDARY")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)

  test("special char field", function()
    local body = [[
--SpecialChar
Content-Disposition: form-data; name="field-ü"
Content-Type: text/plain; charset=utf-8

特殊字符内容
--SpecialChar--
]]
    local expected = { ["field-ü"] = "特殊字符内容" }
    local ret = parse(body, "Content-type: multipart/form-data, boundary=SpecialChar")
    assert(deepEqual(expected, ret), pp.dump({ expected = expected, got = ret }))
  end)
end)
