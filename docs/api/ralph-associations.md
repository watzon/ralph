# Associations

`module`

*Defined in [src/ralph/associations.cr:99](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L99)*

Associations module for defining model relationships

This module provides macros for defining common database associations:
- `belongs_to` - Many-to-one relationship (e.g., a post belongs to a user)
- `has_one` - One-to-one relationship (e.g., a user has one profile)
- `has_many` - One-to-many relationship (e.g., a user has many posts)

Polymorphic associations are also supported:
- `belongs_to :commentable, polymorphic: true` - Can belong to multiple model types
- `has_many :comments, as: :commentable` - Parent side of polymorphic relationship

New in Phase 3.3:
- `counter_cache: true` - Maintain a count column on parent for has_many associations
- `touch: true` - Update parent timestamp when association changes
- Association scoping with lambda blocks
- Through associations: `has_many :tags, through: :posts`

Example:
```
class Post < Ralph::Model
  column id, Int64, primary: true
  column title, String
  column user_id, Int64

  belongs_to user, touch: true
end

class User < Ralph::Model
  column id, Int64, primary: true
  column name, String
  column posts_count, Int32, default: 0
  column updated_at, Time?

  has_one profile
  has_many posts, counter_cache: true
  has_many tags, through: :posts
end
```

## Class Methods

### `.counter_cache_registry`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L124)*

Get the counter cache registry

---

### `.counter_caches_for(child_class : String) : Array(NamedTuple(parent_class: String, association_name: String, counter_column: String, foreign_key: String)) | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L155)*

Get counter caches for a child class

---

### `.find_polymorphic(class_name : String, id_str : String) : Ralph::Model | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L142)*

Lookup and find a polymorphic record by class name and id (as string)
The id is passed as a string to support flexible primary key types

---

### `.polymorphic_registry`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L119)*

Get the polymorphic registry

---

### `.register_counter_cache(child_class : String, parent_class : String, association_name : String, counter_column : String, foreign_key : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L149)*

Register a counter cache relationship

---

### `.register_polymorphic_type(class_name : String, finder : Proc(String, Ralph::Model | Nil))`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L136)*

Register a model class for polymorphic lookup
This is called at runtime when models with `as:` option are loaded
Uses String for flexible primary key type support (Int64, UUID, String, etc.)

---

### `.register_touch(child_class : String, parent_class : String, association_name : String, touch_column : String, foreign_key : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L160)*

Register a touch relationship

---

### `.touch_registry`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L129)*

Get the touch registry

---

### `.touches_for(child_class : String) : Array(NamedTuple(parent_class: String, association_name: String, touch_column: String, foreign_key: String)) | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L166)*

Get touch relationships for a child class

---

## Macros

### `.belongs_to(name, **options)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L195)*

Define a belongs_to association

Options:
- class_name: Specify the class of the association (e.g., "User" instead of inferring from name)
- foreign_key: Specify a custom foreign key column (e.g., "author_id" instead of "user_id")
- primary_key: Specify the primary key on the associated model (defaults to "id")
- polymorphic: If true, this association can belong to multiple model types
- touch: If true, updates parent's updated_at on save; can also be a column name
- counter_cache: If true, maintains a count column on the parent model
  - true: Uses default column name (e.g., `posts_count` for `belongs_to :post`)
  - String: Uses custom column name (e.g., `counter_cache: "comment_count"`)
- optional: If true, the foreign key can be nil (default: false)

Usage:
```
belongs_to user
belongs_to author, class_name: "User"
belongs_to author, class_name: "User", foreign_key: "writer_id"
belongs_to author, class_name: "User", primary_key: "uuid"
belongs_to commentable, polymorphic: true          # Creates commentable_id and commentable_type columns
belongs_to user, touch: true                       # Updates user.updated_at on save
belongs_to user, touch: :last_post_at              # Updates user.last_post_at on save
belongs_to publisher, counter_cache: true          # Maintains publisher.books_count (inferred from child table)
belongs_to publisher, counter_cache: "total_books" # Uses custom column name
```

---

### `.has_many(name, scope_block = nil, **options)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L963)*

Define a has_many association

Options:
- class_name: Specify the class of the association (e.g., "Post" instead of inferring from name)
- foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
- primary_key: Specify the primary key on this model (defaults to "id")
- as: For polymorphic associations, specify the name of the polymorphic interface
- through: For through associations, specify the intermediate association name
- source: For through associations, specify the source association on the through model
- dependent: Specify what happens to associated records when this record is destroyed
  - :destroy - Destroy associated records (runs callbacks)
  - :delete_all - Delete associated records (skips callbacks)
  - :nullify - Set foreign key to NULL
  - :restrict_with_error - Prevent destruction if associations exist (adds error)
  - :restrict_with_exception - Prevent destruction if associations exist (raises exception)

Note: For counter caching, use `counter_cache: true` on the `belongs_to` side of the association.
This automatically generates increment/decrement/update callbacks on the child model.

Usage:
```
has_many posts
has_many articles, class_name: "BlogPost"
has_many articles, class_name: "BlogPost", foreign_key: "writer_id"
has_many posts, dependent: :destroy
has_many posts, dependent: :delete_all
has_many comments, as: :commentable              # Polymorphic association
has_many tags, through: :post_tags               # Through association
has_many tags, through: :post_tags, source: :tag # Through with custom source
```

---

### `.has_one(name, **options)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L596)*

Define a has_one association

Options:
- class_name: Specify the class of the association (e.g., "Profile" instead of inferring from name)
- foreign_key: Specify a custom foreign key on the associated model (e.g., "owner_id" instead of "user_id")
- primary_key: Specify the primary key on this model (defaults to "id")
- as: For polymorphic associations, specify the name of the polymorphic interface
- dependent: Specify what happens to associated records when this record is destroyed
  - :destroy - Destroy associated records (runs callbacks)
  - :delete - Delete associated records (skips callbacks)
  - :nullify - Set foreign key to NULL
  - :restrict_with_error - Prevent destruction if associations exist (adds error)
  - :restrict_with_exception - Prevent destruction if associations exist (raises exception)

Usage:
```
has_one profile
has_one avatar, class_name: "UserAvatar"
has_one avatar, class_name: "UserAvatar", foreign_key: "owner_id"
has_one profile, dependent: :destroy
has_one profile, as: :profileable # Polymorphic association
```

---

