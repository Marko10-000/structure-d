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
module structuresd.dimension.rtree;

private
{
	import core.exception;
	import std.algorithm;
	import std.algorithm.comparison;
	import std.algorithm.sorting;
	import structuresd.dimension;
	import structuresd.utils;
}

/**
 * Do split of a two big container. Innto two lower.
 * @param data Source data to split
 * @param toCompare function to get geometry to compare
 * @return two list for one of the old container and one for the new one
 */
pragma(inline, true)
private pure nothrow T1[][2] _split(T1, size_t MIN, size_t MAX, T2 = T1)(T1[] data, T2 function(T1) nothrow pure toCompare)
in {
	static assert(MIN >= 1);
	assert(2 * MIN <= data.length);
	assert(2 * MAX >= data.length);
}
out(outData) {
	assert(outData[0].length >= MIN);
	assert(outData[0].length <= MAX);
	assert(outData[1].length >= MIN);
	assert(outData[1].length <= MAX);
}
body {
	// Most away
	T1 a = data[0];
	T1 b = data[1];
	while(true)
	{
		T1 tmp = b;
		T2.BASE_TYPE tmp2 = toCompare(b).maxGeometry(toCompare(a)).volume();
		foreach(ref T1 t; data)
		{
			if((t != a) && (t != b))
			{
				if(tmp2 < toCompare(a).maxGeometry(toCompare(t)).volume())
				{
					tmp = t;
					tmp2 = toCompare(a).maxGeometry(toCompare(t)).volume();
				}
			}
		}

		if(tmp == b)
		{
			break;
		}
		else
		{
			b = a;
			a = tmp;
		}
	}

	// Do sorting
	{
		struct SortElement
		{
			T1 t1;
			T2.BASE_TYPE t2;

			this(T1 t)
			{
				t1 = t;
				t2 = min(getInseredVolume(toCompare(a), toCompare(t)), getInseredVolume(toCompare(b), toCompare(t)));
			}

			pragma(inline, true)
			int opCmp(const SortElement b)
			{
				return this.t2 < b.t2 ? -1 : this.t2 > b.t2 ? 1 : 0;
			}
			pragma(inline, true)
			bool opEquals(const SortElement b)
			{
				return this.t2 == b.t2;
			}
		}

		SortElement[] sorted = new SortElement[data.length];
		for(size_t i = 0; i < data.length; i++)
		{
			sorted[i] = SortElement(data[i]);
		}
		size_t tmp = 0;
		sorted.sort.each!((ref SortElement t) { data[tmp] = t.t1; tmp++; });
	}

	// Do split
	T1[] resA = new T1[MAX];
	T1[] resB = new T1[MAX];
	size_t sizeA = 1;
	size_t sizeB = 1;
	resA[0] = a;
	resB[0] = b;
	size_t missing = data.length - 2;
	bool addedA = false;
	bool addedB = false;
	foreach(ref T1 t; data)
	{
		if((a == t) && (!addedA))
		{
			addedA = true;
			continue;
		}
		if((b == t) && (!addedB))
		{
			addedB = true;
			continue;
		}

		if(sizeA + missing == MIN)
		{
			resA[sizeA] = t;
			sizeA++;
		}
		else if(sizeB + missing == MIN)
		{
			resB[sizeB] = t;
			sizeB++;
		}
		else
		{
			if(getInseredVolume(toCompare(a), toCompare(t)) < getInseredVolume(toCompare(b), toCompare(t)))
			{
				resA[sizeA] = t;
				sizeA++;
			}
			else
			{
				resB[sizeB] = t;
				sizeB++;
			}
		}
		missing--;
	}
	return [resA[0..sizeA], resB[0..sizeB]];
}

/**
 * A RTree implementation.
 * @tparam DATA_T The data type that will be insert. It have to be castable to TYPE.
 * @tparam TYPE Is the geometry structure that will be used. It have to match the isGeometry in parent package.
 * @tparam MAX Maximal node size before spilt. MAX have to be at least 3 and odd.
 * @tparam MIN Minimal node isze before merge. MIN have to be greater then 0 and lower or equal to 2 * MAX + 1.
 */
public final class RTree(DATA_T, TYPE, size_t MAX, size_t MIN)
{
	//static assert(isGeometry!TYPE);
	static assert(MAX % 2 == 1);
	static assert(MAX >= 3);
	static assert(MIN * 2 <= MAX + 1);
	static assert(MIN > 0);

	private struct _Node
	{
		public size_t elements = 0;
		public bool isLeave = false;
		public _Node* parent = null;
		public TYPE ownSize;
		union
		{
			public DATA_T[MAX] leaves;
			public _Node*[MAX] nodes;
		}

		pragma(inline, true)
		@nogc
		private nothrow pure _Node* getRoot()
		{
			_Node* current = &this;
			while(current.parent !is null)
			{
				current = current.parent;
			}
			return current;
		}

		public pure nothrow _Node* insert(ref DATA_T toInsert)
		{
			if(this.isLeave)
			{
				if(this.elements < MAX)
				{
					// No split
					this.leaves[this.elements] = toInsert;
					this.elements++;
					this.updateSize!true();
					return this.getRoot();
				}
				else
				{
					// Prepare split
					DATA_T[][2] tmp = _split!(DATA_T, MIN, MAX, TYPE)(this.leaves ~ [toInsert], function TYPE(DATA_T t) => (cast(TYPE) t));
					this.leaves[0..tmp[0].length] = tmp[0];
					this.elements = tmp[0].length;
					this.updateSize!false();

					_Node* newNode = new _Node;
					newNode.isLeave = true;
					newNode.leaves[0..tmp[1].length] = tmp[1];
					newNode.elements = tmp[1].length;
					newNode.updateSize!false();

					// Do split
					if(this.parent is null)
					{
						// New root
						_Node* root = new _Node;
						root.isLeave = false;
						root.elements = 2;
						root.nodes[0..2] = [&this, newNode];
						root.updateSize!false();

						this.parent = root;
						newNode.parent = root;
					}
					else
					{
						// Use root
						this.parent.insert(newNode);
					}
					return this.getRoot();
				}
			}
			else
			{
				// Select min node
				_Node* best = this.nodes[0];
				TYPE.BASE_TYPE bestInsert = getInseredVolume(this.nodes[0].ownSize, cast(TYPE) toInsert);
				foreach(_Node* node; this.nodes)
				{
					TYPE.BASE_TYPE tmp = getInseredVolume(this.nodes[0].ownSize, cast(TYPE) toInsert);
					if(bestInsert > tmp)
					{
						bestInsert = tmp;
						best = node;
					}
				}

				// insert
				return best.insert(toInsert);
			}
		}
		private pure nothrow void insert(_Node* node)
		{
			if(this.elements < MAX)
			{
				// Normal insert
				this.nodes[this.elements] = node;
				this.elements++;
				node.parent = &this;
				this.updateSize!true();
			}
			else
			{
				// Prepare split
				node.parent = &this;
				_Node*[][2] tmp = _split!(_Node*, MIN, MAX, TYPE)(this.nodes ~ [node], function TYPE(_Node* t) => t.ownSize);

				this.elements = tmp[0].length;
				this.nodes[0..tmp[0].length] = tmp[0];
				this.updateSize!false();

				_Node* newNode = new _Node;
				newNode.isLeave = false;
				newNode.elements = tmp[1].length;
				newNode.nodes[0..tmp[1].length] = tmp[1];
				newNode.updateSize!false();
				foreach(_Node* i; tmp[1])
				{
					i.parent = newNode;
				}

				// Split
				if(this.parent == null)
				{
					// New root
					_Node* root = new _Node;
					root.elements = 2;
					root.nodes[0..2] = [&this, newNode];
					root.isLeave = false;
					root.updateSize!false();

					this.parent = root;
					newNode.parent = root;
				}
				else
				{
					// Call parent
					this.parent.insert(newNode);
				}
			}
		}
		pragma(inline, true)
		@nogc
		private pure nothrow void updateSize(bool RECUSIVE)()
		{
			_Node* tmp = &this;
			while(tmp !is null)
			{
				TYPE res = tmp.isLeave ? cast(TYPE)(tmp.leaves[0]) : tmp.nodes[0].ownSize;
				for(size_t i = 1; i < tmp.elements; i++)
				{
					res = res.maxGeometry(tmp.isLeave ? cast(TYPE)(tmp.leaves[i]) : tmp.nodes[i].ownSize);
				}
				tmp.ownSize = res;

				static if(RECUSIVE)
				{
					tmp = tmp.parent;
				}
				else
				{
					return;
				}
			}
		}
	}

	/**
	 * Query iterator to parse queries.
	 */
	public final class QueryIterator
	{
		private _Node* current;
		private size_t index;
		private TYPE range;
		private bool useable;

		pragma(inline, true)
		package pure nothrow this(_Node* root, TYPE range)
		{
			this.current = root;
			this.index = 0;
			this.range = range;
			this.useable = false;
		}

		pragma(inline, true)
		private void toNext()
		{
			while(this.current !is null)
			{
				if(this.index < this.current.elements)
				{
					// Scan if useable
					if(this.current.isLeave)
					{
						if((cast(TYPE) this.current.leaves[this.index]).contains(this.range))
						{
							this.useable = true;
							break;
						}
						else
						{
							this.index++;
						}
					}
					else
					{
						if(this.current.nodes[this.index].ownSize.contains(this.range))
						{
							this.current = this.current.nodes[this.index];
							this.index = 0;
						}
						else
						{
							this.index++;
						}
					}
				}
				else
				{
					// Move up one position
					_Node* old = this.current;
					this.current = old.parent;
					this.index = 0;
					if(this.current is null)
					{
						break;
					}
					while(true)
					{
						if(this.current.nodes[this.index] is old)
						{
							this.index++;
							break;
						}
						else
						{
							this.index++;
							if(this.index >= this.current.elements)
							{
								throw new RangeError("Data structure currupted.");
							}
						}
					}
				}
			}
		}

		pragma(inline, true)
		public void popFront()
		{
			if(!this.useable)
				this.toNext();
			this.useable = false;
			this.index++;
		}
		pragma(inline, true)
		@property
		bool empty()
		{
			if(!useable)
			{
				this.toNext();
				return !this.useable;
			}
			return false;
		}
		pragma(inline, true)
		DATA_T front()
		{
			if(!useable)
			{
				this.toNext();
			}
			if(useable)
			{
				return this.current.leaves[this.index];
			}
			else
			{
				throw new RangeError("Out of range");
			}
		}

		pragma(inline, true)
		int opApply(scope int delegate(DATA_T) func)
		{
			int counter = 0;
			while(!this.empty())
			{
				func(front());
				this.popFront();
				counter++;
			}
			return counter;
		}
	}

	private _Node* _root;

	/**
	 * Generates an RTree structure.
	 */
	public pure nothrow this()
	{
		this._root = new _Node;
		this._root.isLeave = true;
		this._root.elements = 0;
		this._root.parent = null;
	}

	/**
	 *
	 */
	public nothrow pure QueryIterator query(TYPE range)
	{
		return new QueryIterator(this._root, range);
	}

	/**
	 * Insert data to the tree.
	 * @param data Source data to insert.
	 * @return was insert successfully.
	 */
	public pure nothrow bool insert(DATA_T data)
	{
		this._root = this._root.insert(data);
		return true;
	}
}

private unittest
{
	RTree!(Cuboid!2, Cuboid!2, 11, 5) rtree;
}
