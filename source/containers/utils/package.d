/* Supporting different types and containers.
 * Copyright (C) 2017  Marko Semet
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
module structuresd.utils;

private
{
	import std.algorithm.comparison;
	import std.traits;
}

/**
 * Check two function have same enough signature to convert T2 to T1. Result type is a bool.
 * @tparam T1 Base function
 * @tparam T2 Function to check
 */
public enum bool isSameFunction(alias T1, alias T2) = is(typeof(&T1) : typeof(&T2));

/**
 * Check function from two different containers to be equal. Result type is a boolean.
 * BASE_T have to contain a member with the name NAME
 * @tparam BASE_T base type
 * @tparam TYPE_T container to check
 * @tparam NAME name of the member
 */
template isSameContainerFunction(BASE_T, TYPE_T, string NAME)
{
	static assert(__traits(hasMember, BASE_T, NAME));
	public enum bool isSameContainerFunction = __traits(hasMember, TYPE_T, NAME) && isSameFunction!(__traits(getMember, BASE_T, NAME), __traits(getMember, TYPE_T, NAME));
}
