//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Below is a list of unavailable symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.

@_documentation(visibility: internal) @available(*, unavailable, renamed: "LambdaFunctionProtocol")
public typealias HBLambda = LambdaFunctionProtocol
@_documentation(visibility: internal) @available(*, unavailable, renamed: "LambdaRequestContext")
public typealias HBLambdaRequestContext = LambdaRequestContext
@_documentation(visibility: internal) @available(*, unavailable, renamed: "BasicLambdaRequestContext")
public typealias HBBasicLambdaRequestContext = BasicLambdaRequestContext
