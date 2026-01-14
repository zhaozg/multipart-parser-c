# Upstream Issues Tracking

This document tracks and analyzes open issues from the upstream repository iafonov/multipart-parser-c.

**Last Updated**: 2026-01-14

---

## Issue Prioritization

### 🔴 Critical Priority

#### Issue #33: Binary data handling in multipart packets
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/33
- **Opened**: 2022-11-17 by Tibalt
- **Status**: Open, no comments
- **Category**: Bug - Parser Logic

**Problem**: 
Parser fails when binary image data is embedded in multipart packets. The state machine conditions for transitioning from `s_part_data_almost_boundary` to `s_part_data_boundary` are insufficient when boundaries appear directly after binary bytes without CRLF.

**Affected Use Cases**:
- Camera multipart streams with binary images
- Any binary file upload without CRLF before boundary
- Multipart packets with mixed text/binary content

**Technical Details**:
- Works: XML part with CRLF near boundary
- Fails: Binary image data without CRLF before boundary
- Root cause: Missing state transition conditions

**Proposed Solution**:
Add additional conditions to allow state transfer from:
- `s_part_data` → `s_part_data_almost_boundary`
- `s_part_data_almost_boundary` → `s_part_data_boundary`

**Action Items**:
- [ ] Analyze state machine transitions
- [ ] Create test case with binary data
- [ ] Implement fix with proper boundary detection
- [ ] Test with camera multipart streams
- [ ] Ensure no regression for text data

**Priority Justification**: Blocks binary file uploads in certain scenarios - common use case.

---

### 🟡 High Priority

#### Issue #20: RFC boundary format compliance
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/20
- **Opened**: 2014-08-07 by cheneydeng
- **Status**: Open, 8 comments
- **Category**: Bug - RFC Compliance
- **Related**: PR #28

**Problem**:
Misunderstanding of RFC 2046 boundary format. If boundary in HTTP header is "xxyy", then:
- Boundary in body should be: `--xxyy`
- Last boundary should be: `--xxyy--`

Current implementation incorrectly handles the "--" prefix.

**RFC Reference**: RFC 2046 Section 5.1

**Impact**:
- Non-compliant with multipart standard
- May fail with strict RFC-compliant clients/servers
- Interoperability issues

**Discussion Summary** (from comments):
- Multiple users confirmed the issue
- Some debate about exact interpretation
- PR #28 proposed fix

**Action Items**:
- [ ] Review RFC 2046 Section 5.1 carefully
- [ ] Test PR #28 thoroughly
- [ ] Create RFC compliance test suite
- [ ] Validate with real-world multipart data
- [ ] Document breaking changes if any

**Priority Justification**: RFC compliance is critical for interoperability.

---

#### Issue #27: Filename with spaces not supported
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/27
- **Opened**: 2020-04-29 by psvtrajan
- **Status**: Open, 1 comment
- **Category**: Bug - Parsing

**Problem**:
The `handle_headervalue` function uses `strtok()` with both semicolon (`;`) and space (` `) as delimiters. This causes filenames containing spaces to be truncated or parsed incorrectly.

**Example**:
```
Content-Disposition: form-data; name="file"; filename="my document.pdf"
```
Would be parsed incorrectly, splitting at "my" and "document.pdf".

**Technical Analysis**:
- Function: `handle_headervalue()`
- Issue: `strtok(value, "; ")` treats space as delimiter
- Impact: File uploads with spaces in names fail

**Proposed Solution**:
- Parse header value more carefully
- Only split on semicolons, not spaces
- Handle quoted strings properly
- Follow RFC 2183 (Content-Disposition)

**Action Items**:
- [ ] Review header value parsing code
- [ ] Implement proper quoted string handling
- [ ] Test with various filename formats
- [ ] Test with special characters
- [ ] Ensure backward compatibility

**Priority Justification**: Very common use case - files with spaces in names.

---

### 🟢 Medium Priority

#### Issue #22: Data chunk handling issues
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/22
- **Opened**: 2015-07-20 by frostschutz
- **Status**: Open, no comments
- **Category**: API Design

**Problem**:
1. Headers split across chunk boundaries cause double callback invocations
2. `part_data` callback is too granular (1 byte or even 0 byte calls)

**Impact**:
- Users must implement their own buffering
- Performance overhead from excessive callbacks
- Complicates API usage

**Example**:
User receives callbacks for tiny data chunks even though larger chunks are available, requiring additional state tracking and buffering in user code.

**Discussion**:
This is more of an API design issue than a bug. The parser is technically correct but inefficient.

**Potential Solutions**:
1. Buffer internally and emit larger chunks
2. Add API option for minimum chunk size
3. Document buffering requirements clearly
4. Provide utility functions for buffering

**Action Items**:
- [ ] Analyze performance impact
- [ ] Consider API changes vs. documentation
- [ ] Evaluate backward compatibility
- [ ] Propose concrete solution
- [ ] Get community feedback

**Priority Justification**: API usability issue, but workarounds exist.

---

#### Issue #18: Edge cases in binary file uploads
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/18
- **Opened**: 2014-05-08 by shaunkime
- **Status**: Open, no comments
- **Category**: Bug - Edge Cases

**Problem**:
Edge case errors in state transitions when:
- `i == 0` (first byte in chunk)
- `i == is_last` (last byte in chunk)

**Affected States**:
1. `s_part_data_almost_boundary`: LF test fails
2. `s_part_data_boundary`: Boundary doesn't match

**Technical Details**:
The issue includes proposed fixes with debugging logic. Need to:
- Validate the proposed changes
- Test edge cases thoroughly
- Ensure no buffer overruns

**Code Locations**:
- `multipart_parser.c` lines around 228
- State machine boundary handling

**Action Items**:
- [ ] Reproduce edge cases
- [ ] Review proposed fixes
- [ ] Create comprehensive test suite
- [ ] Validate buffer safety
- [ ] Test with various chunk sizes

**Priority Justification**: Edge case but could cause data corruption.

---

### 🔵 Low Priority

#### Issue #14: Multiline headers not supported
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/14
- **Opened**: 2013-10-17 by ladenedge
- **Status**: Open, no comments
- **Category**: Feature - RFC Compliance
- **Related**: PR #15

**Problem**:
RFC 2387 allows multiline headers where continuation lines start with whitespace (space or tab). Parser doesn't handle this.

**Example**:
```
Content-Type: Text/x-Okie; charset=iso-8859-1;
     declaration="<950118.AEB0@XIson.com>"
```

**Current Behavior**:
Only first line is passed to callback.

**Expected Behavior**:
Both lines should be combined or multiple callbacks issued.

**Impact**:
- Rare edge case
- RFC compliance
- Not commonly used in practice

**Solution**: PR #15 available

**Action Items**:
- [ ] Review PR #15
- [ ] Assess if feature is needed
- [ ] Test with multiline headers
- [ ] Document if not implementing

**Priority Justification**: Rare use case, low impact.

---

#### Issue #13: Header value processing with 1-byte feeding
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/13
- **Opened**: 2013-09-11 by DmitriyMaksimov
- **Status**: Open, 1 comment
- **Category**: Bug - Edge Case

**Problem**:
When feeding parser exactly 1 byte at a time, `on_header_value` callback is invoked twice at end of value:
1. Once with len=0 (end signal)
2. Once with len=1 and CR character

**Technical Analysis**:
Missing `break` or `else` in `s_header_value` case.

**Current Code**:
```c
case s_header_value:
    if (c == CR) {
        EMIT_DATA_CB(header_value, buf + mark, i - mark);
        p->state = s_header_value_almost_done;
    }
    if (is_last)
        EMIT_DATA_CB(header_value, buf + mark, (i - mark) + 1);
```

**Proposed Fix**:
Add `else` or `break`:
```c
case s_header_value:
    if (c == CR) {
        EMIT_DATA_CB(header_value, buf + mark, i - mark);
        p->state = s_header_value_almost_done;
        break;  // Add this
    }
    if (is_last)
        EMIT_DATA_CB(header_value, buf + mark, (i - mark) + 1);
```

**Action Items**:
- [ ] Verify the bug exists
- [ ] Apply proposed fix
- [ ] Test with 1-byte feeding
- [ ] Test with normal feeding
- [ ] Check for similar patterns

**Priority Justification**: Very unusual usage pattern (1 byte at a time).

---

### ℹ️ Information Only

#### Issue #26: Release plan inquiry
- **Link**: https://github.com/iafonov/multipart-parser-c/issues/26
- **Opened**: 2018-05-23 by ewwissi
- **Status**: Open, no comments
- **Category**: Question

**Content**: User asking about release plans for the project.

**Action**: No code changes needed. This is a project management question for upstream maintainer.

---

## Priority Summary

| Priority | Count | Issues |
|----------|-------|--------|
| 🔴 Critical | 1 | #33 |
| 🟡 High | 2 | #20, #27 |
| 🟢 Medium | 2 | #22, #18 |
| 🔵 Low | 2 | #14, #13 |
| ℹ️ Info | 1 | #26 |

---

## Recommended Action Plan

### Phase 1: Immediate (Week 1-2)
1. Issue #33 - Binary data handling
   - Create test cases
   - Implement fix
   - Validate thoroughly

2. Issue #27 - Filename with spaces
   - Fix header parsing
   - Test with various filenames

### Phase 2: High Priority (Week 3-4)
1. Issue #20 - RFC compliance
   - Review PR #28
   - Test and merge if good
   - Create RFC test suite

### Phase 3: Medium Priority (Month 2)
1. Issue #18 - Edge cases
   - Reproduce issues
   - Implement fixes
   - Comprehensive testing

2. Issue #22 - API design
   - Analyze options
   - Propose solution
   - Get feedback

### Phase 4: Low Priority (Future)
1. Issues #13, #14 - Edge cases and features
   - Address if time permits
   - Low impact on most users

---

## Testing Strategy

For each issue fix:

1. **Unit Tests**: Isolated test for the specific issue
2. **Integration Tests**: Test in realistic scenarios
3. **Regression Tests**: Ensure no existing functionality breaks
4. **Edge Case Tests**: Boundary conditions, empty inputs, etc.
5. **Performance Tests**: Ensure no significant performance impact

---

## Notes

- Many issues are quite old (2013-2015), suggesting limited upstream maintenance
- Several issues have proposed PRs or solutions in comments
- Binary data handling seems to be a recurring theme (#33, #18, #25)
- RFC compliance needs attention (#20, #14)
- Consider creating a comprehensive test suite that covers all these scenarios

