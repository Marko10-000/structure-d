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
module structuresd.containers.queue;

private
{
	import core.atomic;
}

/**
 * A queue
 */
public class Queue(TYPE, bool THREAD_SAFE = false)
{
	private static struct Entry
	{
		public Entry* next;
		TYPE data;
		bool used;
	}

	private Entry* front;
	private Entry* back;

	pragma(inline, true)
	public this()
	{
		this.front = new Entry;
		this.front.used = true;
		this.front.next = null;
		this.back = this.front;
	}

	pragma(inline, true)
	private void _insert(TYPE data)
	{
		Entry* tmp = new Entry;
		tmp.data = data;
		tmp.used = false;
		tmp.next = null;
		this.back.next = tmp;
		this.back = tmp;
	}
	pragma(inline, true)
	public void insert(TYPES...)(TYPES types)
	{
		static if(THREAD_SAFE)
		{
			synchronized(this)
			{
				static foreach(i; types)
				{
					this._insert(i);
				}
			}
		}
		else
		{
			static foreach(TYPE i; types)
			{
				this._insert(i);
			}
		}
	}

	pragma(inline, true)
	public bool _fetch(ref TYPE data)
	{
		while(true)
		{
			if(!this.front.used)
			{
				this.front.used = true;
				data = this.front.data;
				return true;
			}
			else if(this.front.next !is null)
			{
				this.front = this.front.next;
			}
			else
			{
				return false;
			}
		}
	}
	pragma(inline, true)
	public bool fetch(ref TYPE data)
	{
		static if(THREAD_SAFE)
		{
			synchronized(this)
			{
				return this._fetch(data);
			}
		}
		else
		{
			return this._fetch(data);
		}
	}
}
