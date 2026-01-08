# JoinMacros

`module`

*Defined in [src/ralph/associations.cr:1514](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L1514)*

Join macros - generate join methods for associations

Include this module after defining associations to generate
convenience join methods like `join_posts`, `join_author`, etc.

Example:
```
class User < Ralph::Model
  has_many posts
  include Ralph::JoinMacros
end

# Now you can use:
User.query.join_posts.where("posts.published = ?", true)
```

## Macros

### `.generate_join_methods`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L1516)*

Generate join methods for all associations defined in the class

---

