## Multipart form data parser

### Features
* No dependencies
* Works with chunks of a data - no need to buffer the whole request
* Almost no internal buffering. Buffer size doesn't exceed the size of the boundary (~60-70 bytes)
* **RFC 2046 compliant** - Properly handles boundary format and preamble
* **Memory safe** - Verified with AddressSanitizer and Valgrind
* **Well tested** - 18 functional tests + performance benchmarks
* **CI/CD** - Automated testing, coverage, and profiling

Tested as part of [Cosmonaut](https://github.com/iafonov/cosmonaut) HTTP server.

Implementation based on [node-formidable](https://github.com/felixge/node-formidable) by [Felix Geisendörfer](https://github.com/felixge).

Inspired by [http-parser](https://github.com/joyent/http-parser) by [Ryan Dahl](https://github.com/ry).

### Usage (C)
This parser library works with several callbacks, which the user may set up at application initialization time.

```c
multipart_parser_settings callbacks;

memset(&callbacks, 0, sizeof(multipart_parser_settings));

callbacks.on_header_field = read_header_name;
callbacks.on_header_value = read_header_value;
```

These functions must match the signatures defined in the multipart-parser header file.  For this simple example, we'll just use two of the available callbacks to print all headers the library finds in multipart messages.

Returning a value other than 0 from the callbacks will abort message processing.

```c
int read_header_name(multipart_parser* p, const char *at, size_t length)
{
   printf("%.*s: ", length, at);
   return 0;
}

int read_header_value(multipart_parser* p, const char *at, size_t length)
{
   printf("%.*s\n", length, at);
   return 0;
}
```

When a message arrives, callers must parse the multipart boundary from the **Content-Type** header (see the [RFC](http://tools.ietf.org/html/rfc2387#section-5.1) for more information and examples), and then execute the parser.

```c
multipart_parser* parser = multipart_parser_init(boundary, &callbacks);
multipart_parser_execute(parser, body, length);
multipart_parser_free(parser);
```

### Usage (C++)
In C++, when the callbacks are static member functions it may be helpful to pass the instantiated multipart consumer along as context.  The following (abbreviated) class called `MultipartConsumer` shows how to pass `this` to callback functions in order to access non-static member data.

```cpp
class MultipartConsumer
{
public:
    MultipartConsumer(const std::string& boundary)
    {
        memset(&m_callbacks, 0, sizeof(multipart_parser_settings));
        m_callbacks.on_header_field = ReadHeaderName;
        m_callbacks.on_header_value = ReadHeaderValue;

        m_parser = multipart_parser_init(boundary.c_str(), &m_callbacks);
        multipart_parser_set_data(m_parser, this);
    }

    ~MultipartConsumer()
    {
        multipart_parser_free(m_parser);
    }

    int CountHeaders(const std::string& body)
    {
        multipart_parser_execute(m_parser, body.c_str(), body.size());
        return m_headers;
    }

private:
    static int ReadHeaderName(multipart_parser* p, const char *at, size_t length)
    {
        MultipartConsumer* me = (MultipartConsumer*)multipart_parser_get_data(p);
        me->m_headers++;
    }

    multipart_parser* m_parser;
    multipart_parser_settings m_callbacks;
    int m_headers;
};
```

### Upstream Tracking

This is a fork of [iafonov/multipart-parser-c](https://github.com/iafonov/multipart-parser-c).

We maintain systematic tracking of upstream issues and pull requests:

- **[docs/upstream/TRACKING.md](docs/upstream/TRACKING.md)** - Main tracking document with recommendations
- **[docs/upstream/PR_ANALYSIS.md](docs/upstream/PR_ANALYSIS.md)** - Detailed analysis of upstream PRs
- **[docs/upstream/ISSUES_TRACKING.md](docs/upstream/ISSUES_TRACKING.md)** - Comprehensive issue tracking
- **[docs/HEADER_PARSING_GUIDE.md](docs/HEADER_PARSING_GUIDE.md)** - Guide for parsing header values (e.g., filenames with spaces)

#### Quality Assurance

**Testing & Coverage**:
- 18 functional tests (basic, binary, RFC compliance, regression)
- Code coverage tracking
- Performance benchmarking

**Memory Safety**:
- AddressSanitizer (ASAN) - Detects memory leaks and buffer overflows
- UndefinedBehaviorSanitizer (UBSan) - Detects undefined behavior
- Valgrind memcheck - Memory error detection

**Performance Analysis**:
- Callgrind profiling - Identifies performance hotspots
- Cachegrind profiling - Cache performance analysis
- Continuous benchmarking

See **[docs/ci/CI_GUIDE.md](docs/ci/CI_GUIDE.md)** for complete CI/CD documentation.

#### Quick Status

**Ready to Merge** (Safe improvements):
- PR #29: Check malloc result ✅
- PR #24: Fix missing va_end ✅

**Under Review** (Need testing):
- PR #28: RFC-compliant boundary processing ⚠️
- Issue #33: Binary data handling in multipart packets 🔴

See [docs/upstream/TRACKING.md](docs/upstream/TRACKING.md) for full analysis.

#### Automated Tracking

We provide automated upstream tracking:
- **Script**: `scripts/check-upstream.sh` - Manual check for new issues/PRs
- **GitHub Action**: `.github/workflows/upstream-tracking.yml` - Weekly automated checks
- **GitHub Action**: `.github/workflows/ci.yml` - Automated testing and analysis

---

### Contributors
* [Daniel T. Wagner](http://www.danieltwagner.de/)
* [James McLaughlin](http://udp.github.com/)
* [Jay Miller](http://www.cryptofreak.org)

© 2012 [Igor Afonov](http://iafonov.github.com)
