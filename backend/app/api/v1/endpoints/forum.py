from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.forum import ForumPost, ForumComment
from app.schemas.forum import (
    ForumPostCreate,
    ForumPostOut,
    ForumPostDetailOut,
    ForumCommentCreate,
    ForumCommentOut,
)

router = APIRouter()

@router.get("/posts", response_model=List[ForumPostOut])
def list_posts(
    category: str = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve forum post discussions.
    """
    query = db.query(ForumPost)
    if category and category != "All":
        query = query.filter(ForumPost.category == category)

    posts = query.order_by(ForumPost.created_at.desc()).offset(skip).limit(limit).all()
    results = []
    for p in posts:
        p_out = ForumPostOut.model_validate(p)
        author = db.query(User).filter(User.id == p.author_id).first()
        p_out.author_name = author.username if author else "Farmer"
        p_out.comments_count = db.query(func.count(ForumComment.id)).filter(ForumComment.post_id == p.id).scalar() or 0
        results.append(p_out)
    return results

@router.post("/posts", response_model=ForumPostOut, status_code=status.HTTP_201_CREATED)
def create_post(
    post_in: ForumPostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Create a new community forum discussion post.
    """
    post = ForumPost(
        author_id=current_user.id,
        title=post_in.title,
        content=post_in.content,
        category=post_in.category or "General"
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    p_out = ForumPostOut.model_validate(post)
    p_out.author_name = current_user.username
    p_out.comments_count = 0
    return p_out

@router.get("/posts/{post_id}", response_model=ForumPostDetailOut)
def get_post_detail(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve forum thread detail with all comments.
    """
    post = db.query(ForumPost).filter(ForumPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Forum post not found")

    p_out = ForumPostDetailOut.model_validate(post)
    author = db.query(User).filter(User.id == post.author_id).first()
    p_out.author_name = author.username if author else "Farmer"

    comments = db.query(ForumComment).filter(ForumComment.post_id == post_id).order_by(ForumComment.created_at.asc()).all()
    c_outs = []
    for c in comments:
        c_out = ForumCommentOut.model_validate(c)
        c_author = db.query(User).filter(User.id == c.author_id).first()
        c_out.author_name = c_author.username if c_author else "Member"
        c_outs.append(c_out)

    p_out.comments = c_outs
    p_out.comments_count = len(c_outs)
    return p_out

@router.post("/posts/{post_id}/comments", response_model=ForumCommentOut, status_code=status.HTTP_201_CREATED)
def add_comment(
    post_id: str,
    comment_in: ForumCommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Add a comment to a forum thread post.
    """
    post = db.query(ForumPost).filter(ForumPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Forum post not found")

    comment = ForumComment(
        post_id=post_id,
        author_id=current_user.id,
        content=comment_in.content
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)

    c_out = ForumCommentOut.model_validate(comment)
    c_out.author_name = current_user.username
    return c_out

@router.post("/posts/{post_id}/like", response_model=ForumPostOut)
def like_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Upvote/like a forum post.
    """
    post = db.query(ForumPost).filter(ForumPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Forum post not found")

    post.likes_count += 1
    db.commit()
    db.refresh(post)

    p_out = ForumPostOut.model_validate(post)
    author = db.query(User).filter(User.id == post.author_id).first()
    p_out.author_name = author.username if author else "Farmer"
    p_out.comments_count = db.query(func.count(ForumComment.id)).filter(ForumComment.post_id == post.id).scalar() or 0
    return p_out
