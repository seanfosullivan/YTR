from datetime import datetime
from typing import List
from feedgen.feed import FeedGenerator

def generate_rss_feed(
    videos: List[dict],
    feed_title: str,
    feed_description: str,
    feed_link: str,
    feed_language: str = "en",
) -> str:
    """
    Generate an RSS feed from a list of videos.
    
    Args:
        videos: List of video dicts with keys: name, size, last_modified, content_type
        feed_title: Title of the RSS feed
        feed_description: Description of the RSS feed
        feed_link: Base URL for the RSS feed service
        feed_language: Language code for the feed
    
    Returns:
        RSS feed XML as string
    """
    fg = FeedGenerator()
    fg.title(feed_title)
    fg.description(feed_description)
    fg.link(href=feed_link, rel="self")
    fg.language(feed_language)
    fg.lastBuildDate(datetime.utcnow())
    
    for video in videos:
        object_name = video["name"]
        size = video.get("size", 0)
        last_modified = video.get("last_modified")
        content_type = video.get("content_type", "video/mp4")
        
        # Generate video URL (proxy endpoint)
        video_url = f"{feed_link.rstrip('/')}/video/{object_name}"
        
        # Create RSS item
        fe = fg.add_entry()
        fe.title(object_name)
        fe.link(href=video_url)
        fe.enclosure(url=video_url, length=str(size), type=content_type)
        
        if last_modified:
            if isinstance(last_modified, datetime):
                fe.pubDate(last_modified)
            else:
                # Try to parse if it's a string
                try:
                    fe.pubDate(datetime.fromisoformat(str(last_modified).replace("Z", "+00:00")))
                except (ValueError, AttributeError):
                    fe.pubDate(datetime.utcnow())
        else:
            fe.pubDate(datetime.utcnow())
    
    return fg.rss_str(pretty=True).decode("utf-8")
