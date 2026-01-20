/* Lua binding for multipart-parser-c
 * Compatible with Lua 5.1, Lua 5.2, Lua 5.3, LuaJIT 2.0+
 * MIT License
 */

#include <lauxlib.h>
#include <lua.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>
#include "multipart_parser.h"

#define MULTIPART_PARSER_MT "multipart_parser"
#define LMP_ERROR_BUFFER_SIZE 256

/* Lua 5.1 compatibility - only for non-LuaJIT Lua 5.1 */
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM == 501 && \
    !defined(LUAJIT_VERSION)

#define lua_rawlen lua_objlen

#ifndef luaL_newlib
#define luaL_newlib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))
#endif

#ifndef luaL_setfuncs
#define luaL_setfuncs(L, l, n) (assert(n == 0), luaL_register(L, NULL, l))
#endif

#endif

/* Structure to hold parser and Lua state */
typedef struct {
  multipart_parser* parser;
  lua_State* L;
  int callbacks_ref;
  multipart_parser_settings settings;
  char last_error[LMP_ERROR_BUFFER_SIZE];  /* Store last Lua callback error */
} lua_multipart_parser;

/* Helper to get callback function from table */
static int get_callback(lua_State* L, int ref, char const* name) {
  /* Ensure we have enough stack space:
   * 1 slot for rawgeti result (registry table)
   * 1 slot for getfield result (callback function)
   * 1 slot for margin during lua_remove operation
   */
  if (!lua_checkstack(L, 3)) {
    return 0;
  }

  lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  lua_getfield(L, -1, name);
  if (lua_isfunction(L, -1)) {
    lua_remove(L, -2);
    return 1;
  }
  lua_pop(L, 2);
  return 0;
}

/* Helper function to store Lua callback error
 * Note: snprintf is safe and will not overflow the buffer - it automatically
 * truncates if the formatted string exceeds the buffer size.
 */
static void store_callback_error(lua_multipart_parser* lmp, lua_State* L, char const* callback_name) {
  char const* err = lua_tostring(L, -1);
  if (err) {
    snprintf(lmp->last_error, sizeof(lmp->last_error), "%s: %s", callback_name, err);
  } else {
    snprintf(lmp->last_error, sizeof(lmp->last_error), "%s: unknown error", callback_name);
  }
}

/* Callback implementations */
static int on_header_field_cb(multipart_parser* p, char const* at,
                              size_t length) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 4)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_header_field"))
    return 0;

  lua_pushlstring(L, at, length);
  if (lua_pcall(L, 1, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_header_field");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_header_value_cb(multipart_parser* p, char const* at,
                              size_t length) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 4)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_header_value")) return 0;

  lua_pushlstring(L, at, length);
  if (lua_pcall(L, 1, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_header_value");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_part_data_cb(multipart_parser* p, char const* at, size_t length) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 4)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_part_data")) return 0;

  lua_pushlstring(L, at, length);
  if (lua_pcall(L, 1, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_part_data");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_part_data_begin_cb(multipart_parser* p) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 3)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_part_data_begin")) return 0;

  if (lua_pcall(L, 0, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_part_data_begin");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_headers_complete_cb(multipart_parser* p) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 3)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_headers_complete")) return 0;

  if (lua_pcall(L, 0, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_headers_complete");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_part_data_end_cb(multipart_parser* p) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 3)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_part_data_end")) return 0;

  if (lua_pcall(L, 0, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_part_data_end");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

static int on_body_end_cb(multipart_parser* p) {
  lua_multipart_parser* lmp;
  lua_State* L;
  int result;

  lmp = (lua_multipart_parser*)multipart_parser_get_data(p);
  assert(lmp && lmp->L);

  L = lmp->L;

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 3)) {
    return -1;
  }

  if (!get_callback(L, lmp->callbacks_ref, "on_body_end")) return 0;

  if (lua_pcall(L, 0, 1, 0) != 0) {
    store_callback_error(lmp, L, "on_body_end");
    lua_pop(L, 1);
    return -1;
  }

  result = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
  lua_pop(L, 1);
  return result;
}

/* Lua API: multipart_parser.new(boundary, callbacks) */
static int lmp_new(lua_State* L) {
  char const* boundary;
  lua_multipart_parser* lmp;

  /* Get boundary string */
  boundary = luaL_checkstring(L, 1);

  /* Get callbacks table (optional) */
  if (!lua_isnoneornil(L, 2)) {
    luaL_checktype(L, 2, LUA_TTABLE);
  }

  /* Create userdata */
  lmp = (lua_multipart_parser*)lua_newuserdata(L, sizeof(lua_multipart_parser));
  if (!lmp) {
    return luaL_error(L, "Failed to allocate memory for parser");
  }

  /* Initialize */
  lmp->parser = NULL;
  lmp->L = L;
  lmp->callbacks_ref = LUA_NOREF;
  lmp->last_error[0] = '\0';

  /* Set metatable */
  luaL_getmetatable(L, MULTIPART_PARSER_MT);
  lua_setmetatable(L, -2);

  /* Store callbacks table in registry */
  if (!lua_isnoneornil(L, 2)) {
    lua_pushvalue(L, 2);
    lmp->callbacks_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  }

  /* Setup callbacks in the structure's settings */
  memset(&lmp->settings, 0, sizeof(multipart_parser_settings));
  lmp->settings.on_header_field = on_header_field_cb;
  lmp->settings.on_header_value = on_header_value_cb;
  lmp->settings.on_part_data = on_part_data_cb;
  lmp->settings.on_part_data_begin = on_part_data_begin_cb;
  lmp->settings.on_headers_complete = on_headers_complete_cb;
  lmp->settings.on_part_data_end = on_part_data_end_cb;
  lmp->settings.on_body_end = on_body_end_cb;

  /* Initialize parser with pointer to our settings */
  lmp->parser = multipart_parser_init(boundary, &lmp->settings);
  if (!lmp->parser) {
    /* Clean up callbacks_ref to prevent memory leak */
    if (lmp->callbacks_ref != LUA_NOREF) {
      luaL_unref(L, LUA_REGISTRYINDEX, lmp->callbacks_ref);
      lmp->callbacks_ref = LUA_NOREF;
    }
    return luaL_error(L, "Failed to initialize multipart parser");
  }

  /* Set user data */
  multipart_parser_set_data(lmp->parser, lmp);

  return 1;
}

/* Lua API: parser:execute(data) */
static int lmp_execute(lua_State* L) {
  lua_multipart_parser* lmp;
  char const* data;
  size_t len;
  size_t parsed;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  /* Get string data pointer - CRITICAL: The string at index 2 must remain
   * on the stack during multipart_parser_execute() because:
   * 1. Callbacks may trigger Lua GC via lua_pcall()
   * 2. GC safety: As long as the string stays on stack, it won't be collected
   * 3. The 'data' pointer remains valid throughout execution
   * We explicitly do NOT pop the string before multipart_parser_execute
   * completes.
   */
  data = luaL_checklstring(L, 2, &len);

  if (!lmp->parser) {
    return luaL_error(L, "Parser already freed");
  }

  /* Execute parser - the 'data' pointer is safe because index 2 is still on
   * stack */
  parsed = multipart_parser_execute(lmp->parser, data, len);

  lua_pushinteger(L, parsed);
  return 1;
}

/* Lua API: parser:get_error() */
static int lmp_get_error(lua_State* L) {
  lua_multipart_parser* lmp;
  multipart_parser_error err;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  if (!lmp->parser) {
    return luaL_error(L, "Parser already freed");
  }

  err = multipart_parser_get_error(lmp->parser);
  lua_pushinteger(L, err);
  return 1;
}

/* Lua API: parser:get_error_message() */
static int lmp_get_error_message(lua_State* L) {
  lua_multipart_parser* lmp;
  char const* msg;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  if (!lmp->parser) {
    return luaL_error(L, "Parser already freed");
  }

  msg = multipart_parser_get_error_message(lmp->parser);
  lua_pushstring(L, msg);
  return 1;
}

/* Lua API: parser:get_last_lua_error() */
static int lmp_get_last_lua_error(lua_State* L) {
  lua_multipart_parser* lmp;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  if (lmp->last_error[0] != '\0') {
    lua_pushstring(L, lmp->last_error);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

/* Lua API: parser:reset(boundary) */
static int lmp_reset(lua_State* L) {
  lua_multipart_parser* lmp;
  char const* boundary;
  int result;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  if (!lmp->parser) {
    return luaL_error(L, "Parser already freed");
  }

  /* Get new boundary (optional - if nil, keeps existing boundary) */
  if (lua_isnoneornil(L, 2)) {
    boundary = NULL;
  } else {
    boundary = luaL_checkstring(L, 2);
  }

  result = multipart_parser_reset(lmp->parser, boundary);

  if (result != 0) {
    return luaL_error(L, "Failed to reset parser: new boundary too long");
  }

  /* Clear last error on reset */
  lmp->last_error[0] = '\0';

  lua_pushboolean(L, 1);
  return 1;
}

/* Lua API: parser:free() */
static int lmp_free(lua_State* L) {
  lua_multipart_parser* lmp;

  lmp = (lua_multipart_parser*)luaL_checkudata(L, 1, MULTIPART_PARSER_MT);

  if (lmp->parser) {
    multipart_parser_free(lmp->parser);
    lmp->parser = NULL;
  }

  if (lmp->callbacks_ref != LUA_NOREF) {
    luaL_unref(L, LUA_REGISTRYINDEX, lmp->callbacks_ref);
    lmp->callbacks_ref = LUA_NOREF;
  }

  return 0;
}

/* Metatable methods */
static luaL_Reg const parser_methods[] = {
    {"execute", lmp_execute},
    {"get_error", lmp_get_error},
    {"get_error_message", lmp_get_error_message},
    {"get_last_lua_error", lmp_get_last_lua_error},
    {"reset", lmp_reset},
    {"free", lmp_free},
    {NULL, NULL}};

/* ========================================================================
 * Simple/Fast Parse Interface (uvs_multipart_parse compatible)
 * ======================================================================== */

/* Simple callback: read header field name */
static int simple_read_header_field(multipart_parser* p, char const* at,
                                    size_t length) {
  lua_State* L = (lua_State*)multipart_parser_get_data(p);

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 2)) {
    return -1;
  }

  lua_pushlstring(L, at, length);
  return 0;
}

/* Simple callback: read header value and store key-value pair */
static int simple_read_header_value(multipart_parser* p, char const* at,
                                    size_t length) {
  lua_State* L = (lua_State*)multipart_parser_get_data(p);

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 2)) {
    return -1;
  }

  lua_pushlstring(L, at, length);
  lua_rawset(L, -3);
  return 0;
}

/* Simple callback: read part data and append to array */
static int simple_read_part_data(multipart_parser* p, char const* at,
                                 size_t length) {
  size_t idx;
  lua_State* L = (lua_State*)multipart_parser_get_data(p);

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 2)) {
    return -1;
  }

  idx = lua_rawlen(L, -1);
  lua_pushlstring(L, at, length);
  lua_rawseti(L, -2, idx + 1);
  return 0;
}

/* Simple callback: begin new part - create table for it */
static int simple_on_part_data_begin(multipart_parser* p) {
  lua_State* L = (lua_State*)multipart_parser_get_data(p);

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 2)) {
    return -1;
  }

  lua_createtable(L, 8, 16);
  return 0;
}

/* Simple callback: end part - add to parts array */
static int simple_on_part_data_end(multipart_parser* p) {
  size_t idx;
  lua_State* L = (lua_State*)multipart_parser_get_data(p);

  /* Ensure enough stack space (see stack requirements in file header) */
  if (!lua_checkstack(L, 2)) {
    return -1;
  }

  idx = lua_rawlen(L, -2);
  lua_rawseti(L, -2, idx + 1);
  return 0;
}

/* Simple parse function: multipart_parser.parse(boundary, body) -> table or
 * (nil, error) */
static int lmp_parse(lua_State* L) {
  char const* boundary;
  char const* body;
  size_t length;
  multipart_parser* parser;
  multipart_parser_settings settings;
  size_t parsed;

  /* Get arguments */
  boundary = luaL_checkstring(L, 1);
  body = luaL_checklstring(L, 2, &length);

  /* Setup simple callbacks */
  memset(&settings, 0, sizeof(multipart_parser_settings));
  settings.on_header_field = simple_read_header_field;
  settings.on_header_value = simple_read_header_value;
  settings.on_part_data = simple_read_part_data;
  settings.on_part_data_begin = simple_on_part_data_begin;
  settings.on_part_data_end = simple_on_part_data_end;

  /* Create parser */
  parser = multipart_parser_init(boundary, &settings);
  if (!parser) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to initialize parser");
    return 2;
  }

  /* Set Lua state as user data */
  multipart_parser_set_data(parser, L);

  /* Create result table */
  lua_createtable(L, 4, 4);

  /* Parse */
  parsed = multipart_parser_execute(parser, body, length);

  /* Check result */
  if (parsed == length) {
    /* Success - result table is on stack */
    multipart_parser_free(parser);
    return 1;
  } else {
    /* Error - return nil and error position */
    char const* errmsg = multipart_parser_get_error_message(parser);

    multipart_parser_free(parser);

    lua_pop(L, 1); /* Pop result table */
    lua_pushnil(L);
    lua_pushfstring(L, "%s (at position %d)", errmsg, (int)parsed);
    return 2;
  }
}

/* Module functions */
static luaL_Reg const module_funcs[] = {
  {"new", lmp_new},
  {"parse", lmp_parse},

  {NULL, NULL}
};

/* Error codes table */
static void create_error_codes(lua_State* L) {
  lua_newtable(L);

  lua_pushinteger(L, MPPE_OK);
  lua_setfield(L, -2, "OK");

  lua_pushinteger(L, MPPE_PAUSED);
  lua_setfield(L, -2, "PAUSED");

  lua_pushinteger(L, MPPE_INVALID_BOUNDARY);
  lua_setfield(L, -2, "INVALID_BOUNDARY");

  lua_pushinteger(L, MPPE_INVALID_HEADER_FIELD);
  lua_setfield(L, -2, "INVALID_HEADER_FIELD");

  lua_pushinteger(L, MPPE_INVALID_HEADER_FORMAT);
  lua_setfield(L, -2, "INVALID_HEADER_FORMAT");

  lua_pushinteger(L, MPPE_INVALID_STATE);
  lua_setfield(L, -2, "INVALID_STATE");

  lua_pushinteger(L, MPPE_UNKNOWN);
  lua_setfield(L, -2, "UNKNOWN");

  lua_setfield(L, -2, "ERROR");
}

/* Module initialization */
int luaopen_multipart_parser(lua_State* L) {
  /* Create metatable */
  luaL_newmetatable(L, MULTIPART_PARSER_MT);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmp_free);
  lua_setfield(L, -2, "__gc");
  luaL_setfuncs(L, parser_methods, 0);
  lua_pop(L, 1);

  /* Create module table */
  lua_newtable(L);
  luaL_setfuncs(L, module_funcs, 0);

  /* Add error codes */
  create_error_codes(L);

  /* Add version */
  lua_pushstring(L, "1.0.0");
  lua_setfield(L, -2, "_VERSION");

  return 1;
}
