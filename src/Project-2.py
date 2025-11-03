import csv
import json
import pandas as pd
import subprocess
import os

# --------------------------
# Linked-list memory DB
# --------------------------
class Node:
    def __init__(self, data, next=None, prev=None):
        self.data = data
        self.next = next
        self.prev = prev

class MemoryDB:
    def __init__(self):
        self.head = None
        self.tail = None

    def append(self, data):
        new_node = Node(data, None, self.tail)
        if self.tail:
            self.tail.next = new_node
        else:
            self.head = new_node
        self.tail = new_node

def load_csv_to_memorydb(path):
    df = pd.read_csv(path)
    df.columns = [c.strip().lower() for c in df.columns]

    db = MemoryDB()
    for _, row in df.iterrows():
        db.append(row.to_dict())
    return db, df


# --------------------------
# Huffman tree
# --------------------------
class HuffmanNode:
    def __init__(self, char, freq, left=None, right=None):
        self.char = char
        self.freq = freq
        self.left = left
        self.right = right

def build_huffman_tree(freq):
    if not freq:
        raise ValueError("Empty frequency map")
    if len(freq) == 1:
        k, v = next(iter(freq.items()))
        return HuffmanNode(k, v)

    heap = [HuffmanNode(k, v) for k, v in freq.items()]
    step = 1
    while len(heap) > 1:
        heap.sort(key=lambda x: x.freq)
        left = heap.pop(0)
        right = heap.pop(0)
        merged = HuffmanNode("", left.freq + right.freq, left, right)
        print(f"Huff step {step}: merged '{left.char}'({left.freq}) and '{right.char}'({right.freq}) → {merged.freq}")
        heap.append(merged)
        step += 1
    return heap[0]

def build_huffman_codes(node, prefix="", codes=None):
    if codes is None:
        codes = {}
    if node.left is None and node.right is None:
        codes[node.char] = prefix if prefix else "0"
        return codes
    if node.left:
        build_huffman_codes(node.left, prefix + "0", codes)
    if node.right:
        build_huffman_codes(node.right, prefix + "1", codes)
    return codes


# --------------------------
# Red-Black Tree
# --------------------------
class RBNode:
    def __init__(self, key, color="red", left=None, right=None, parent=None):
        self.key = key
        self.color = color
        self.left = left
        self.right = right
        self.parent = parent

class RedBlackTree:
    def __init__(self):
        self.root = None

    def left_rotate(self, x):
        y = x.right
        if not y:
            return
        x.right = y.left
        if y.left:
            y.left.parent = x
        y.parent = x.parent
        if not x.parent:
            self.root = y
        elif x == x.parent.left:
            x.parent.left = y
        else:
            x.parent.right = y
        y.left = x
        x.parent = y

    def right_rotate(self, y):
        x = y.left
        if not x:
            return
        y.left = x.right
        if x.right:
            x.right.parent = y
        x.parent = y.parent
        if not y.parent:
            self.root = x
        elif y == y.parent.right:
            y.parent.right = x
        else:
            y.parent.left = x
        x.right = y
        y.parent = x

    def insert_fixup(self, z):
        while z.parent and z.parent.color == "red":
            if not z.parent.parent:
                break
            if z.parent == z.parent.parent.left:
                y = z.parent.parent.right
                if y and y.color == "red":
                    z.parent.color = "black"
                    y.color = "black"
                    z.parent.parent.color = "red"
                    z = z.parent.parent
                else:
                    if z == z.parent.right:
                        z = z.parent
                        self.left_rotate(z)
                    z.parent.color = "black"
                    z.parent.parent.color = "red"
                    self.right_rotate(z.parent.parent)
            else:
                y = z.parent.parent.left
                if y and y.color == "red":
                    z.parent.color = "black"
                    y.color = "black"
                    z.parent.parent.color = "red"
                    z = z.parent.parent
                else:
                    if z == z.parent.left:
                        z = z.parent
                        self.right_rotate(z)
                    z.parent.color = "black"
                    z.parent.parent.color = "red"
                    self.left_rotate(z.parent.parent)
        if self.root:
            self.root.color = "black"

    def insert(self, key):
        z = RBNode(str(key))
        y = None
        x = self.root
        while x:
            y = x
            x = x.left if key < x.key else x.right
        z.parent = y
        if not y:
            self.root = z
        elif key < y.key:
            y.left = z
        else:
            y.right = z
        self.insert_fixup(z)

    def visualize(self, node=None, indent="", last=True, visited=None):
        if visited is None:
            visited = set()
        if node is None:
            node = self.root
        if node is None or id(node) in visited:
            return
        visited.add(id(node))

        print(indent, "└─ " if last else "├─ ", f"{node.key} ({node.color})", sep="")
        indent += "   " if last else "│  "
        self.visualize(node.left, indent, False, visited)
        self.visualize(node.right, indent, True, visited)



# --------------------------
# Main
# --------------------------
def main():
    path = "student-data.csv"
    memdb, df = load_csv_to_memorydb(path)
    print(f"Loaded CSV into memory-linked database. Rows: {len(df)}")
    print(df.columns.tolist())

    if "famsize" not in df.columns or "age" not in df.columns:
        raise ValueError("CSV must contain 'famsize' and 'age' columns.")

    combined_tokens = []
    node = memdb.head
    while node:
        fs = str(node.data.get("famsize", ""))
        ag = str(node.data.get("age", ""))
        token = f"{fs}_{ag}"
        node.data["famsize_age"] = token
        combined_tokens.append(token)
        node = node.next

    df["famsize_age"] = combined_tokens
    print("Added combined 'famsize_age' column to DataFrame.")

    # --- Huffman Section ---
    print("\n--- Building Huffman index on 'famsize_age' ---")
    freq = {}
    for t in combined_tokens:
        freq[t] = freq.get(t, 0) + 1

    root = build_huffman_tree(freq)
    codes = build_huffman_codes(root)

    print("\nHuffman Codes (token => code):")
    for k in sorted(codes):
        print(f"{k} => {codes[k]}")

    with open("python_huffman_famsize_age.json", "w") as f:
        json.dump(codes, f, indent=2)
    print("Exported Huffman codes to python_huffman_famsize_age.json")

    # --- Red-Black Tree Section ---
    print("\n--- Building Red-Black Tree index on 'famsize_age' ---")
    rb_tree = RedBlackTree()
    for t in combined_tokens:
        rb_tree.insert(t)

    print("\nVisualizing Red-Black Tree:")
    rb_tree.visualize()

    # Export to DOT
    dot_file = "python_rb_tree_visual.dot"
    png_file = "python_rb_tree_visual.png"
    with open(dot_file, "w") as f:
        f.write("digraph RBTree {\nnode [shape=circle, style=filled, fontname=\"Arial\"];\n")

        def write_dot(node):
            if not node:
                return
            color = "red" if node.color == "red" else "black"
            f.write(f"\"{node.key}\" [fillcolor=\"{color}\", fontcolor=\"white\"];\n")
            if node.left:
                f.write(f"\"{node.key}\" -> \"{node.left.key}\";\n")
                write_dot(node.left)
            if node.right:
                f.write(f"\"{node.key}\" -> \"{node.right.key}\";\n")
                write_dot(node.right)
        write_dot(rb_tree.root)
        f.write("}\n")
    print(f"Exported Red-Black tree visualization to {dot_file}")

    try:
        subprocess.run(["dot", "-Tpng", dot_file, "-o", png_file], check=True)
        print(f"PNG visualization generated: {png_file}")
    except Exception as e:
        print("Could not generate PNG. Make sure Graphviz is installed and 'dot' is in your PATH.")
        print("Error:", e)

    def rb_to_dict(node):
        if not node:
            return None
        return {
            "key": node.key,
            "color": node.color,
            "left": rb_to_dict(node.left),
            "right": rb_to_dict(node.right)
        }

    with open("python_rb_tree_structure.json", "w") as f:
        json.dump(rb_to_dict(rb_tree.root), f, indent=2)
    print("Exported Red-Black tree structure to rb_tree_structure.json")

    df[["famsize_age"]].to_csv("python-student-data-famsize-age.csv", index=False)
    print("Saved merged data only to student-data-famsize-age.csv")


if __name__ == "__main__":
    main()
