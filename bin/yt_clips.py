import sys
print(f"DEBUG: Running with Python executable: {sys.executable}")
print(f"DEBUG: Python sys.path: {sys.path}")
#!/usr/bin/env python
from youtube_transcript_api import YouTubeTranscriptApi
from pydantic import BaseModel, Field
from typing import List, Generator, Iterable
import instructor
import google.generativeai as genai
from google.generativeai import types as genai_types
import logging
import inspect

logging.basicConfig(level=logging.INFO)

SYSTEM_PROMPT = """You are given a sequence of YouTube transcripts and your job
is to return notable clips that can be recut as smaller videos. Give very
specific titles and descriptions. Make sure the length of clips is proportional
to the length of the video. Note that this is a transcript and so there might
be spelling errors. Note that and correct any spellings. Use the context to
make sure you're spelling things correctly."""

# Directly use the GenerativeModel from google.generativeai
model = genai.GenerativeModel(
    model_name="gemini-2.0-pro-exp",
    system_instruction=SYSTEM_PROMPT
    # We might need to add generation_config={'response_mime_type': 'application/json'}
    # if Gemini supports it directly, or ensure the prompt requests JSON.
)


def extract_video_id(url: str) -> str | None:
    import re

    match = re.search(r"v=([a-zA-Z0-9_-]+)", url)
    if match:
        return match.group(1)


class TranscriptSegment(BaseModel):
    source_id: int
    start: float
    text: str


def get_transcript_with_timing(
    video_id: str,
) -> Generator[TranscriptSegment, None, None]:
    """
    Fetches the transcript of a YouTube video along with the start and end times
    for each text segment, and returns them as a list of Pydantic models.
    """
    transcript = YouTubeTranscriptApi.get_transcript(video_id)
    for ii, segment in enumerate(transcript):
        yield TranscriptSegment(
            source_id=ii, start=segment["start"], text=segment["text"]
        )


class YoutubeClip(BaseModel):
    title: str = Field(description="Specific and informative title for the clip.")
    description: str = Field(
        description="A detailed description of the clip, including notable quotes or phrases."
    )
    start: float
    end: float


class YoutubeClips(BaseModel):
    clips: List[YoutubeClip]


def yield_clips(segments: Iterable[TranscriptSegment]) -> Iterable[YoutubeClips]:
    user_prompt = f"Let's use the following transcript segments.\n{segments}"
    logging.info(f"Type of model: {type(model)}")
    logging.info(f"Model object: {model}")
    if hasattr(model, "generate_content"):
        logging.info(f"model.generate_content method: {model.generate_content}")
        logging.info(f"Module of model.generate_content: {inspect.getmodule(model.generate_content)}")
        try:
            logging.info(f"Signature of model.generate_content: {inspect.signature(model.generate_content)}")
        except Exception as e:
            logging.info(f"Could not get signature of model.generate_content: {e}")
    else:
        logging.info("Model does not have generate_content attribute")
    # Non-streaming call directly to google-generativeai
    response = model.generate_content(
        user_prompt,
        generation_config=genai_types.GenerationConfig(response_mime_type="application/json")
    )
    # Assuming response.text contains the JSON string
    # It might be in response.parts[0].text depending on the exact structure Gemini returns
    # We'll start with response.text and adjust if needed based on errors or logging.
    try:
        json_string = response.text
        logging.info(f"Raw JSON response from Gemini: {json_string}")
        clips_object = YoutubeClips.model_validate_json(json_string)
        yield clips_object # Yield the single complete object
    except Exception as e:
        logging.error(f"Error processing or parsing Gemini response: {e}")
        logging.error(f"Full Gemini response object: {response}")
        # Optionally, re-raise the exception or handle it as appropriate
        raise


# Example usage
if __name__ == "__main__":
    from rich.table import Table
    from rich.console import Console
    from rich.prompt import Prompt

    console = Console()
    url = Prompt.ask("Enter a YouTube URL")

    with console.status("[bold green]Processing YouTube URL...") as status:
        video_id = extract_video_id(url)

        if video_id is None:
            raise ValueError("Invalid YouTube video URL")

        transcript = list(get_transcript_with_timing(video_id))
        status.update("[bold green]Generating clips...")

        for clip in yield_clips(transcript):
            console.clear()

            table = Table(title="Extracted YouTube Clips", padding=(0, 1))

            table.add_column("Title", style="cyan")
            table.add_column("Description", style="magenta")
            table.add_column("Start", justify="right", style="green")
            table.add_column("End", justify="right", style="green")
            for youtube_clip in clip.clips or []:
                table.add_row(
                    youtube_clip.title,
                    youtube_clip.description,
                    str(youtube_clip.start),
                    str(youtube_clip.end),
                )
            console.print(table)
