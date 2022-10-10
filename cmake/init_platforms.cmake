#
# Copyright (C) 2022 Intel Corporation
#
# SPDX-License-Identifier: MIT
#

set(MAX_CORE 64)

set(ALL_CORE_TYPES "")
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake${BRANCH_DIR_SUFFIX}fill_core_types.cmake)

set(ALL_CORE_TYPES_REVERSED ${ALL_CORE_TYPES})
list(REVERSE ALL_CORE_TYPES_REVERSED)

macro(FIND_IDX_FOR_CORE_TYPE CORE_TYPE CORE_IDX)
  list(FIND ALL_CORE_TYPES "${CORE_TYPE}" CORE_IDX)
  if(${CORE_IDX} EQUAL -1)
    message(FATAL_ERROR "No ${CORE_TYPE} allowed, exiting")
  endif()
endmacro()

macro(INIT_LIST LIST_TYPE ELEMENT_TYPE)
  foreach(IT RANGE 0 ${MAX_CORE} 1)
    list(APPEND ALL_${ELEMENT_TYPE}_${LIST_TYPE} " ")
  endforeach()
endmacro()

macro(GET_LIST_FOR_CORE_TYPE LIST_TYPE ELEMENT_TYPE CORE_IDX OUT_LIST)
  list(GET ALL_${ELEMENT_TYPE}_${LIST_TYPE} ${CORE_IDX} CORE_X_${LIST_TYPE})
  string(REPLACE "," ";" ${OUT_LIST} ${CORE_X_${LIST_TYPE}})
endmacro()

macro(ADD_ITEM_FOR_CORE_TYPE LIST_TYPE ELEMENT_TYPE CORE_TYPE ITEM)
  FIND_IDX_FOR_CORE_TYPE(${CORE_TYPE} CORE_IDX)
  list(GET ALL_${ELEMENT_TYPE}_${LIST_TYPE} ${CORE_IDX} CORE_X_LIST)
  string(REPLACE " " "" CORE_X_LIST ${CORE_X_LIST})
  if("${CORE_X_LIST}" STREQUAL "")
    set(CORE_X_LIST "${ITEM}")
  else()
    set(CORE_X_LIST "${CORE_X_LIST},${ITEM}")
  endif()
  list(REMOVE_AT ALL_${ELEMENT_TYPE}_${LIST_TYPE} ${CORE_IDX})
  list(INSERT ALL_${ELEMENT_TYPE}_${LIST_TYPE} ${CORE_IDX} ${CORE_X_LIST})
endmacro()

macro(CORE_CONTAINS_PLATFORMS TYPE CORE_TYPE OUT_FLAG)
  FIND_IDX_FOR_CORE_TYPE(${CORE_TYPE} CORE_IDX)
  GET_LIST_FOR_CORE_TYPE("PLATFORMS" ${TYPE} ${CORE_IDX} CORE_X_PLATFORMS)
  string(REPLACE " " "" CORE_X_PLATFORMS ${CORE_X_PLATFORMS})
  if("${CORE_X_PLATFORMS}" STREQUAL "")
    set(${OUT_FLAG} FALSE)
  else()
    set(${OUT_FLAG} TRUE)
  endif()
endmacro()

macro(INIT_PRODUCTS_LIST TYPE)
  list(APPEND ALL_${TYPE}_PRODUCT_FAMILY " ")
endmacro()

macro(GET_AVAILABLE_PLATFORMS TYPE FLAG_NAME OUT_STR)
  set(${TYPE}_PLATFORM_LIST)
  set(${TYPE}_CORE_FLAGS_DEFINITONS)
  foreach(CORE_TYPE ${ALL_CORE_TYPES_REVERSED})
    CORE_CONTAINS_PLATFORMS(${TYPE} ${CORE_TYPE} COREX_HAS_PLATFORMS)
    if(COREX_HAS_PLATFORMS)
      FIND_IDX_FOR_CORE_TYPE(${CORE_TYPE} CORE_IDX)
      list(APPEND ${TYPE}_CORE_FLAGS_DEFINITONS ${FLAG_NAME}_${CORE_TYPE})
      GET_LIST_FOR_CORE_TYPE("PLATFORMS" ${TYPE} ${CORE_IDX} ${TYPE}_COREX_PLATFORMS)
      list(APPEND ${TYPE}_PLATFORM_LIST ${${TYPE}_COREX_PLATFORMS})
    endif()
  endforeach()
  foreach(PLATFORM_IT ${${TYPE}_PLATFORM_LIST})
    set(${OUT_STR} "${${OUT_STR}} ${PLATFORM_IT}")
    list(APPEND ${TYPE}_CORE_FLAGS_DEFINITONS ${FLAG_NAME}_${PLATFORM_IT})
  endforeach()
endmacro()

macro(GET_PLATFORMS_FOR_CORE_TYPE TYPE CORE_TYPE OUT_LIST)
  FIND_IDX_FOR_CORE_TYPE(${CORE_TYPE} CORE_IDX)
  GET_LIST_FOR_CORE_TYPE("PLATFORMS" ${TYPE} ${CORE_IDX} ${OUT_LIST})
endmacro()

# default flag for CoreX devices support
set(SUPPORT_GEN_DEFAULT TRUE CACHE BOOL "default value for SUPPORT_COREx")
# default flag for platform support
set(SUPPORT_PLATFORM_DEFAULT TRUE CACHE BOOL "default value for support platform")

# Define the hardware configurations we support and test
macro(SET_FLAGS_FOR CORE_TYPE)
  foreach(SKU_NAME ${ARGN})
    if(SUPPORT_${SKU_NAME})
      if(NOT SUPPORT_${CORE_TYPE})
        message(STATUS "Auto-Enabling ${CORE_TYPE} support for ${SKU_NAME}")
        set(SUPPORT_${CORE_TYPE} TRUE CACHE BOOL "Support ${CORE_TYPE} devices" FORCE)
      endif()
      if(NOT TESTS_${CORE_TYPE})
        message(STATUS "Auto-Enabling ${CORE_TYPE} tests for ${SKU_NAME}")
        set(TESTS_${CORE_TYPE} TRUE CACHE BOOL "Build ULTs for ${CORE_TYPE} devices" FORCE)
      endif()
    endif()
    string(TOLOWER ${CORE_TYPE} MAP_${SKU_NAME}_CORE_lower)
    string(TOLOWER ${SKU_NAME} MAP_${SKU_NAME}_lower)
    set(MAP_${SKU_NAME}_CORE_lower "${CORE_PREFIX}${MAP_${SKU_NAME}_CORE_lower}${CORE_SUFFIX}" CACHE STRING "Core name for SKU" FORCE)
    set(MAP_${SKU_NAME}_lower ${MAP_${SKU_NAME}_lower} CACHE STRING "SKU in lower case" FORCE)
  endforeach()

  set(SUPPORT_${CORE_TYPE} ${SUPPORT_GEN_DEFAULT} CACHE BOOL "Support ${CORE_TYPE} devices")
  set(TESTS_${CORE_TYPE} ${SUPPORT_${CORE_TYPE}} CACHE BOOL "Build ULTs for ${CORE_TYPE} devices")

  if(NOT SUPPORT_${CORE_TYPE} OR NOT aubstream_build_tests)
    set(TESTS_${CORE_TYPE} FALSE)
  endif()

  if(SUPPORT_${CORE_TYPE})
    list(APPEND ALL_SUPPORTED_CORE_FAMILIES ${CORE_TYPE})
    list(REMOVE_DUPLICATES ALL_SUPPORTED_CORE_FAMILIES)

    foreach(${CORE_TYPE}_PLATFORM ${ARGN})
      set(SUPPORT_${${CORE_TYPE}_PLATFORM} ${SUPPORT_PLATFORM_DEFAULT} CACHE BOOL "Support ${${CORE_TYPE}_PLATFORM}")
      if(TESTS_${CORE_TYPE})
        set(TESTS_${${CORE_TYPE}_PLATFORM} ${SUPPORT_${${CORE_TYPE}_PLATFORM}} CACHE BOOL "Build ULTs for ${${CORE_TYPE}_PLATFORM}")
      endif()
      if(NOT SUPPORT_${${CORE_TYPE}_PLATFORM} OR NOT TESTS_${CORE_TYPE} OR NOT aubstream_build_tests)
        set(TESTS_${${CORE_TYPE}_PLATFORM} FALSE)
      endif()
    endforeach()
  endif()

  if(TESTS_${CORE_TYPE})
    list(APPEND ALL_TESTED_CORE_FAMILIES ${CORE_TYPE})
    list(REMOVE_DUPLICATES ALL_TESTED_CORE_FAMILIES)
  endif()
endmacro()

macro(DISABLE_FLAGS_FOR CORE_TYPE)
  set(SUPPORT_${CORE_TYPE} FALSE CACHE BOOL "Support ${CORE_TYPE} devices" FORCE)
  set(TESTS_${CORE_TYPE} FALSE CACHE BOOL "Build ULTs for ${CORE_TYPE} devices" FORCE)
  foreach(SKU_NAME ${ARGN})
    set(SUPPORT_${SKU_NAME} FALSE CACHE BOOL "Support ${SKU_NAME}" FORCE)
    set(TESTS_${SKU_NAME} FALSE CACHE BOOL "Build ULTs for ${SKU_NAME}" FORCE)
  endforeach()
endmacro()

macro(ADD_PLATFORM_FOR_CORE_TYPE LIST_TYPE CORE_TYPE PLATFORM_NAME)
  ADD_ITEM_FOR_CORE_TYPE("PLATFORMS" ${LIST_TYPE} ${CORE_TYPE} ${PLATFORM_NAME})
endmacro()

# Init lists
INIT_LIST("PLATFORMS" "SUPPORTED")
INIT_LIST("PLATFORMS" "TESTED")
INIT_PRODUCTS_LIST("TESTED")
INIT_PRODUCTS_LIST("SUPPORTED")

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake${BRANCH_DIR_SUFFIX}setup_platform_flags.cmake)

# Get platform lists, flag definition and set default platforms
GET_AVAILABLE_PLATFORMS("SUPPORTED" "SUPPORT" ALL_AVAILABLE_SUPPORTED_PLATFORMS)
GET_AVAILABLE_PLATFORMS("TESTED" "TESTS" ALL_AVAILABLE_TESTED_PLATFORMS)

# Output platforms
message(STATUS "[Aubstream] All supported platforms: ${ALL_AVAILABLE_SUPPORTED_PLATFORMS}")
message(STATUS "[Aubstream] All tested platforms: ${ALL_AVAILABLE_TESTED_PLATFORMS}")

# Output families
message(STATUS "[Aubstream] All supported core families: ${ALL_SUPPORTED_CORE_FAMILIES}")
message(STATUS "[Aubstream] All tested core families: ${ALL_TESTED_CORE_FAMILIES}")
