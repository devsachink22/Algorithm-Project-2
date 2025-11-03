# memorydb_huffman_rb.jl
using CSV
using DataFrames
using JSON

# --------------------------
# Linked-list memory DB
# --------------------------
mutable struct Node
    data::Dict{String, Any}
    next::Union{Node, Nothing}
    prev::Union{Node, Nothing}
end

mutable struct MemoryDB
    head::Union{Node, Nothing}
    tail::Union{Node, Nothing}
end

function MemoryDB()
    MemoryDB(nothing, nothing)
end

function append!(db::MemoryDB, data::Dict{String, Any})
    new_node = Node(data, nothing, db.tail)
    if db.tail !== nothing
        db.tail.next = new_node
    else
        db.head = new_node
    end
    db.tail = new_node
end

function load_csv_to_memorydb(path::AbstractString)
    df = CSV.read(path, DataFrame)

    # --- Clean column names: remove spaces and lowercase them ---
    rename!(df, Dict(name => lowercase(strip(String(name))) for name in names(df)))

    db = MemoryDB()
    for row in eachrow(df)
        # convert row to Dict{String,Any}
        append!(db, Dict(string(k) => v for (k, v) in pairs(row)))
    end
    return db, df
end

# --------------------------
# Huffman tree (simple)
# --------------------------
mutable struct HuffmanNode
    char::String
    freq::Int
    left::Union{HuffmanNode, Nothing}
    right::Union{HuffmanNode, Nothing}
end

function build_huffman_tree(freq::Dict{String, Int})
    # If there is only one symbol, create a root with that symbol and freq
    if length(freq) == 0
        error("Empty frequency map")
    elseif length(freq) == 1
        (k, v) = first(freq)
        return HuffmanNode(k, v, nothing, nothing)
    end

    heap = [HuffmanNode(k, v, nothing, nothing) for (k, v) in freq]
    step = 1
    while length(heap) > 1
        sort!(heap, by = x -> x.freq)  # smallest first
        left = popfirst!(heap)
        right = popfirst!(heap)
        merged = HuffmanNode("", left.freq + right.freq, left, right)
        println("Huff step $step: merged '", left.char, "'(", left.freq, ") and '", right.char, "'(", right.freq, ") → ", merged.freq)
        push!(heap, merged)
        step += 1
    end
    return heap[1]
end

function build_huffman_codes(node::HuffmanNode, prefix::String = "", codes::Dict{String,String}=Dict{String,String}())
    # If leaf
    if node.left === nothing && node.right === nothing
        # Edge case: if prefix is empty (single unique token in dataset), give "0"
        codes[node.char] = prefix == "" ? "0" : prefix
        return codes
    end
    if node.left !== nothing
        build_huffman_codes(node.left, prefix * "0", codes)
    end
    if node.right !== nothing
        build_huffman_codes(node.right, prefix * "1", codes)
    end
    return codes
end

# --------------------------
# Red-Black tree (string keys)
# --------------------------
mutable struct RBNode
    key::String
    color::Symbol  # :red or :black
    left::Union{RBNode, Nothing}
    right::Union{RBNode, Nothing}
    parent::Union{RBNode, Nothing}
end

mutable struct RedBlackTree
    root::Union{RBNode, Nothing}
end

function RedBlackTree()
    RedBlackTree(nothing)
end

function left_rotate(tree::RedBlackTree, x::RBNode)
    y = x.right
    if y === nothing
        return
    end
    x.right = y.left
    if y.left !== nothing
        y.left.parent = x
    end
    y.parent = x.parent
    if x.parent === nothing
        tree.root = y
    elseif x === x.parent.left
        x.parent.left = y
    else
        x.parent.right = y
    end
    y.left = x
    x.parent = y
end

function right_rotate(tree::RedBlackTree, y::RBNode)
    x = y.left
    if x === nothing
        return
    end
    y.left = x.right
    if x.right !== nothing
        x.right.parent = y
    end
    x.parent = y.parent
    if y.parent === nothing
        tree.root = x
    elseif y === y.parent.right
        y.parent.right = x
    else
        y.parent.left = x
    end
    x.right = y
    y.parent = x
end

function insert_fixup(tree::RedBlackTree, z::RBNode)
    while z.parent !== nothing && z.parent.color == :red
        if z.parent.parent === nothing
            break
        end
        if z.parent === z.parent.parent.left
            y = z.parent.parent.right
            if y !== nothing && y.color == :red
                z.parent.color = :black
                y.color = :black
                z.parent.parent.color = :red
                z = z.parent.parent
            else
                if z === z.parent.right
                    z = z.parent
                    left_rotate(tree, z)
                end
                z.parent.color = :black
                z.parent.parent.color = :red
                right_rotate(tree, z.parent.parent)
            end
        else
            y = z.parent.parent.left
            if y !== nothing && y.color == :red
                z.parent.color = :black
                y.color = :black
                z.parent.parent.color = :red
                z = z.parent.parent
            else
                if z === z.parent.left
                    z = z.parent
                    right_rotate(tree, z)
                end
                z.parent.color = :black
                z.parent.parent.color = :red
                left_rotate(tree, z.parent.parent)
            end
        end
    end
    if tree.root !== nothing
        tree.root.color = :black
    end
end

function insert!(tree::RedBlackTree, key::AbstractString)
    z = RBNode(String(key), :red, nothing, nothing, nothing)
    y = nothing
    x = tree.root
    while x !== nothing
        y = x
        if key < x.key
            x = x.left
        else
            x = x.right
        end
    end
    z.parent = y
    if y === nothing
        tree.root = z
    elseif key < y.key
        y.left = z
    else
        y.right = z
    end
    insert_fixup(tree, z)
end

function visualize_rb_tree(node::Union{RBNode, Nothing}, indent::String = "", last = true)
    if node === nothing
        return
    end
    print(indent)
    print(last ? "└─ " : "├─ ")
    println(node.key, " (", node.color, ")")
    indent *= last ? "   " : "│  "
    visualize_rb_tree(node.left, indent, false)
    visualize_rb_tree(node.right, indent, true)
end

# --------------------------
# Main
# --------------------------
function main()
    path = "student-data.csv"
    memdb, df = load_csv_to_memorydb(path)
    println("Loaded CSV into memory-linked database. Rows: ", nrow(df))
    println(names(df))

    # --- Clean and normalize column names ---
    rename!(df, Dict(name => lowercase(strip(String(name))) for name in names(df)))

    # --- Verify columns ---
    if !("famsize" in names(df)) || !("age" in names(df))
        error("CSV must contain 'famsize' and 'age' columns. Found: ", names(df))
    end

    # --- Merge famsize + age ---
    combined_tokens = String[]
    node = memdb.head
    while node !== nothing
        fs_key = haskey(node.data, "famsize") ? "famsize" :
                 haskey(node.data, :famsize) ? :famsize : nothing
        ag_key = haskey(node.data, "age") ? "age" :
                 haskey(node.data, :age) ? :age : nothing

        if fs_key === nothing || ag_key === nothing
            node = node.next
            continue
        end

        fs = string(node.data[fs_key])
        ag = string(node.data[ag_key])
        token = fs * "_" * ag
        node.data["famsize_age"] = token
        push!(combined_tokens, token)
        node = node.next
    end

    df[!, :famsize_age] = combined_tokens
    println("Added combined 'famsize_age' column to DataFrame.")

    # =====================================================
    # ============== HUFFMAN TREE SECTION =================
    # =====================================================
    println("\n--- Building Huffman index on 'famsize_age' ---")
    freq = Dict{String, Int}()
    for t in combined_tokens
        freq[t] = get(freq, t, 0) + 1
    end

    root = build_huffman_tree(freq)
    codes = build_huffman_codes(root)

    println("\nHuffman Codes (token => code):")
    for (k, v) in sort(collect(codes), by = x -> x[1])
        println(k, " => ", v)
    end

    # === Export Huffman Codes ===
    json_path = "julia_huffman_famsize_age.json"
    open(json_path, "w") do io
        JSON.print(io, codes, 2)
    end
    println("Exported Huffman codes to $json_path")

    # =====================================================
    # ============== RED-BLACK TREE SECTION ===============
    # =====================================================
    println("\n--- Building Red-Black Tree index on 'famsize_age' ---")
    rb_tree = RedBlackTree()
    for t in combined_tokens
        insert!(rb_tree, t)
    end

    println("\nVisualizing Red-Black Tree:")
    visualize_rb_tree(rb_tree.root)

    # === Export Visualization ===
    dot_file = "julia_rb_tree_visual.dot"
    png_file = "julia_rb_tree_visual.png"
    open(dot_file, "w") do io
        println(io, "digraph RBTree {")
        println(io, "node [shape=circle, style=filled, fontname=\"Arial\"];")

        function write_dot(node::Union{RBNode, Nothing})
            node === nothing && return
            color = node.color == :red ? "red" : "black"
            fontcolor = node.color == :red ? "white" : "white"
            println(io, "\"$(node.key)\" [fillcolor=\"$color\", fontcolor=\"$fontcolor\"];")

            if node.left !== nothing
                println(io, "\"$(node.key)\" -> \"$(node.left.key)\";")
                write_dot(node.left)
            end
            if node.right !== nothing
                println(io, "\"$(node.key)\" -> \"$(node.right.key)\";")
                write_dot(node.right)
            end
        end

        write_dot(rb_tree.root)
        println(io, "}")
    end
    println("Exported Red-Black tree visualization to $dot_file")
    
    # === Generate PNG using Graphviz ===
    try
        run(`dot -Tpng $dot_file -o $png_file`)
        println("PNG visualization generated: $png_file")
    catch e
        println("Could not generate PNG. Make sure Graphviz is installed and 'dot' is in your PATH.")
        println("Error: ", e)
    end

    # === Export RB tree as JSON (optional structured format) ===
    function rb_to_dict(node::Union{RBNode, Nothing})
        node === nothing && return nothing
        return Dict(
            "key" => node.key,
            "color" => String(node.color),
            "left" => rb_to_dict(node.left),
            "right" => rb_to_dict(node.right)
        )
    end

    rb_json = rb_to_dict(rb_tree.root)
    open("julia_rb_tree_structure.json", "w") do io
        JSON.print(io, rb_json, 2)
    end
    println("Exported Red-Black tree structure to rb_tree_structure.json")

    # === Save CSV with merged column ===
    merged_df = DataFrame(famsize_age = combined_tokens)
    CSV.write("julia-student-data-famsize-age.csv", merged_df)
    println("Saved merged data only to student-data-famsize-age.csv")
end

main()