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
module structuresd.dimension;

private
{
	import std.meta;
	import std.traits;
	import structuresd.utils;
}

public final struct Point(uint DIMS, TYPE = double)
{
	private static pure
	{
		enum bool goodSingualType(T) = __traits(compiles, {T a; TYPE b = a;});
		bool suiableTypes(T...)()
		{
			bool result = true;
			static foreach(I; T)
			{
				static if(!goodSingualType!I && !(__traits(isSame, TemplateOf!I, Point) && goodSingualType!(TemplateArgsOf!I[1])))
				{
					result = false;
				}
			}
			return result;
		}
		ulong countDims(T...)()
		{
			ulong result = 0;
			static foreach(I; T)
			{
				static if(goodSingualType!I)
				{
					result++;
				}
				else static if(__traits(isSame, TemplateOf!I, Point) && goodSingualType!(TemplateArgsOf!I[1]))
				{
					result += TemplateArgsOf!I[0];
				}
				else
				{
					static assert(false);
				}
			}
			return result;
		}
	}

	public TYPE[DIMS] dims;

	public this(T...)(T data) if(suiableTypes!T && countDims!T == DIMS)
	{
		ulong position = 0;
		static foreach(i; data)
		{
			static if(goodSingualType!(typeof(i)))
			{
				this.dims[position] = i;
				position++;
			}
			else static if(__traits(isSame, TemplateOf!(typeof(i)), Point) && goodSingualType!(TemplateArgsOf!(typeof(i))[1]))
			{
				static foreach(j; i.dims)
				{
					this.dims[position] = j;
					position++;
				}
			}
			else
			{
				static assert(false);
			}
		}
	}
	public this(TYPE[DIMS] dims)
	{
		this.dims = dims;
	}

	public Point!(DIMS, TYPE) opBinary(string OP)(TYPE scalar) if(OP == "*" || OP == "/")
	{
		Point!(DIMS, TYPE) result;
		static foreach(uint i; 0..DIMS)
		{
			mixin("result.dims[i] = this.dims[i] " ~ OP ~ " scalar;");
		}
		return result;
	}

	public Point!(DIMS, TYPE) opBinary(string OP)(Point p) if(OP == "+" || OP == "-")
	{
		Point!(DIMS, TYPE) result;
		static foreach(uint i; 0..DIMS)
		{
			mixin("result.dims[i] = this.dims[i] " ~ OP ~ " p.dims[i];");
		}
		return result;
	}

	public ref Point!(DIMS, TYPE) opOpAssign(string OP)(Point!(DIMS, TYPE) p) if(OP == "+" || OP == "-")
	{
		static foreach(uint i; 0..DIMS)
		{
			mixin("this.dims[i] " ~ OP ~ "= p.dims[i];");
		}
		return this;
	}
}

private struct _GeometryFuns(T1, T2)
{
	public nothrow pure T1 maxGeometry(T1) { T1 res; return res; }
	public nothrow pure T2 volume() { T2 res; return res; };
	public nothrow pure bool contains(T1) { return false; };
}

public final struct Sphere(uint DIMS, TYPE = double)
{
	static assert(DIMS > 0);

	public Point!(DIMS, TYPE) center;
	public TYPE radius;
}

public final struct Cuboid(uint DIMS, TYPE = double)
{
	public alias BASE_TYPE = TYPE;

	public Point!(DIMS, TYPE) a;
	public Point!(DIMS, TYPE) b;

	public this(Point!(DIMS, TYPE) a, Point!(DIMS, TYPE) b)
	{
		static foreach(ulong i; 0..DIMS)
		{
			this.a.dims[i] = min(a.dims[i], b.dims[i]);
			this.b.dims[i] = max(a.dims[i], b.dims[i]);
		}
	}

	public nothrow pure Cuboid maxGeometry(Cuboid c)
	{
		Cuboid res;
		static foreach(uint i; 0..DIMS)
		{
			res.a.dims[i] = min(this.a.dims[i], this.b.dims[i], c.a.dims[i], c.b.dims[i]);
			res.b.dims[i] = max(this.a.dims[i], this.b.dims[i], c.a.dims[i], c.b.dims[i]);
		}
		return res;
	}
	public nothrow pure TYPE volume()
	{
		TYPE res;
		for(uint i = 0; i < DIMS; i++)
		{
			res *= this.b.dims[i] - this.b.dims[i];
		}
		return res < 0 ? -res : res;
	}
	public nothrow pure bool containsPoint(Point!(DIMS, TYPE) p)
	{
		static foreach(ulong i; 0..DIMS)
		{
			if((min(this.a.dims[i], this.b.dims[i]) > p.dims[i]) | (p.dims[i] > max(this.a.dims[i], this.b.dims[i])))
			{
				return false;
			}
		}
		return true;
	}
	public nothrow pure bool contains(Cuboid c)
	{
		return this.allDotsCheck(c) && c.allDotsCheck(this);
	}

	private pure nothrow bool allDotsCheck(Cuboid c)
	{
		foreach(ulong i; 0..(1 << DIMS))
		{
			TYPE[DIMS] tmp;
			static foreach(ulong j; 0..DIMS)
			{
				tmp[j] = ((1 << j) & i) == 0 ? this.a.dims[j] : this.b.dims[j];
			}
			if(this.containsPoint(Point!(DIMS, TYPE)(tmp)))
			{
				return true;
			}
		}
		return false;
	}
}

public enum bool isGeometry(T) = __traits(hasMember, T, "BASE_TYPE") &&
                                 isSameContainerFunction!(_GeometryFuns!(T, T.BASE_TYPE), T, "maxGeometry") &&
                                 isSameContainerFunction!(_GeometryFuns!(T, T.BASE_TYPE), T, "volume") &&
                                 isSameContainerFunction!(_GeometryFuns!(T, T.BASE_TYPE), T, "contains");


public TYPE.BASE_TYPE getInseredVolume(TYPE)(TYPE old, TYPE insert) if(isGeometry!(TYPE))
{
	return old.maxGeometry(insert).volume() - old.volume();
}

private unittest
{
	static assert(isSameContainerFunction!(_GeometryFuns!(Cuboid!2, Cuboid!(2).BASE_TYPE), Cuboid!2, "maxGeometry"));
	static assert(isSameContainerFunction!(_GeometryFuns!(Cuboid!2, Cuboid!(2).BASE_TYPE), Cuboid!2, "volume"));
	static assert(isSameContainerFunction!(_GeometryFuns!(Cuboid!2, Cuboid!(2).BASE_TYPE), Cuboid!2, "contains"));
	static assert(isGeometry!(Cuboid!2));
}
