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
module structuresd.serialize;


private
{
	import std.traits;
	import structuresd.utils;
}


/**
 * Mark attribute as serializable
 */
public enum SERIALIZE;


/**
 * Check if type is serialize.
 * @tparam TYPE Type to check.
 */
public template isSerialize(TYPE)
{
	static if(is(TYPE == struct))
	{
		enum bool isSerialize = listSerializeMembers!TYPE.length > 0;
	}
	else static if(__traits(isArithmetic, TYPE))
	{
		enum bool isSerialize = true;
	}
	else
	{
		enum bool isSerialize = false;
	}
}

/**
 * List members
 */
public alias listSerializeMembers(TYPE) = membersWith!(_listSerializeMembers, TYPE);
private alias _listSerializeMembers(alias T) = hasAttribute!(SERIALIZE, T);
