-- Database Setup for Chatbot UI
-- This script combines all necessary migrations

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Function to handle storage objects
CREATE OR REPLACE FUNCTION delete_storage_object(bucket TEXT, object TEXT, OUT status INT, OUT content TEXT)
RETURNS RECORD
LANGUAGE 'plpgsql' SECURITY DEFINER
AS $$
DECLARE
  project_url TEXT := 'http://supabase_kong_chatbotui:8000';
  service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
  url TEXT := project_url || '/storage/v1/object/' || bucket || '/' || object;
BEGIN
  SELECT
      INTO status, content
           result.status::INT, result.content::TEXT
      FROM extensions.http((
    'DELETE',
    url,
    ARRAY[extensions.http_header('authorization','Bearer ' || service_role_key)],
    NULL,
    NULL)::extensions.http_request) AS result;
END;
$$;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    bio TEXT NOT NULL DEFAULT '',
    has_onboarded BOOLEAN NOT NULL DEFAULT FALSE,
    image_url TEXT NOT NULL DEFAULT '',
    image_path TEXT NOT NULL DEFAULT '',
    profile_context TEXT NOT NULL DEFAULT '',
    display_name TEXT NOT NULL DEFAULT 'User',
    use_azure_openai BOOLEAN NOT NULL DEFAULT FALSE,
    username TEXT NOT NULL UNIQUE DEFAULT 'user' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
    anthropic_api_key TEXT,
    azure_openai_35_turbo_id TEXT,
    azure_openai_45_turbo_id TEXT,
    azure_openai_45_vision_id TEXT,
    azure_openai_api_key TEXT,
    azure_openai_endpoint TEXT,
    google_gemini_api_key TEXT,
    mistral_api_key TEXT,
    openai_api_key TEXT,
    openai_organization_id TEXT,
    perplexity_api_key TEXT,
    CONSTRAINT profiles_bio_check CHECK ((char_length(bio) <= 500)),
    CONSTRAINT profiles_image_url_check CHECK ((char_length(image_url) <= 1000)),
    CONSTRAINT profiles_image_path_check CHECK ((char_length(image_path) <= 1000)),
    CONSTRAINT profiles_profile_context_check CHECK ((char_length(profile_context) <= 1500)),
    CONSTRAINT profiles_display_name_check CHECK ((char_length(display_name) <= 100)),
    CONSTRAINT profiles_username_check CHECK (((char_length(username) >= 3) AND (char_length(username) <= 25))),
    CONSTRAINT profiles_anthropic_api_key_check CHECK ((char_length(anthropic_api_key) <= 1000)),
    CONSTRAINT profiles_azure_openai_35_turbo_id_check CHECK ((char_length(azure_openai_35_turbo_id) <= 1000)),
    CONSTRAINT profiles_azure_openai_45_turbo_id_check CHECK ((char_length(azure_openai_45_turbo_id) <= 1000)),
    CONSTRAINT profiles_azure_openai_45_vision_id_check CHECK ((char_length(azure_openai_45_vision_id) <= 1000)),
    CONSTRAINT profiles_azure_openai_api_key_check CHECK ((char_length(azure_openai_api_key) <= 1000)),
    CONSTRAINT profiles_azure_openai_endpoint_check CHECK ((char_length(azure_openai_endpoint) <= 1000)),
    CONSTRAINT profiles_google_gemini_api_key_check CHECK ((char_length(google_gemini_api_key) <= 1000)),
    CONSTRAINT profiles_mistral_api_key_check CHECK ((char_length(mistral_api_key) <= 1000)),
    CONSTRAINT profiles_openai_api_key_check CHECK ((char_length(openai_api_key) <= 1000)),
    CONSTRAINT profiles_openai_organization_id_check CHECK ((char_length(openai_organization_id) <= 1000)),
    CONSTRAINT profiles_perplexity_api_key_check CHECK ((char_length(perplexity_api_key) <= 1000))
);

-- Create workspaces table
CREATE TABLE IF NOT EXISTS public.workspaces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    description TEXT NOT NULL DEFAULT '',
    embeddings_provider TEXT NOT NULL DEFAULT 'openai',
    include_profile_context BOOLEAN NOT NULL DEFAULT TRUE,
    include_workspace_instructions BOOLEAN NOT NULL DEFAULT TRUE,
    is_home BOOLEAN NOT NULL DEFAULT FALSE,
    name TEXT NOT NULL DEFAULT 'New Workspace',
    sharing TEXT NOT NULL DEFAULT 'private',
    default_model_id TEXT,
    CONSTRAINT workspaces_description_check CHECK ((char_length(description) <= 500)),
    CONSTRAINT workspaces_embeddings_provider_check CHECK ((char_length(embeddings_provider) <= 100)),
    CONSTRAINT workspaces_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT workspaces_sharing_check CHECK (((sharing)::text = ANY ((ARRAY['private'::character varying, 'workspace'::character varying, 'public'::character varying])::text[]))),
    CONSTRAINT workspaces_default_model_id_check CHECK ((char_length(default_model_id) <= 1000))
);

-- Create folders table
CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Folder',
    type TEXT NOT NULL,
    CONSTRAINT folders_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT folders_type_check CHECK (((type)::text = ANY ((ARRAY['chat'::character varying, 'prompt'::character varying, 'file'::character varying, 'model'::character varying])::text[])))
);

-- Create files table
CREATE TABLE IF NOT EXISTS public.files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES folders(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New File',
    type TEXT NOT NULL DEFAULT 'text/plain',
    size INTEGER NOT NULL DEFAULT 0,
    file_path TEXT,
    in_trash BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT files_name_check CHECK ((char_length(name) <= 1000)),
    CONSTRAINT files_type_check CHECK ((char_length(type) <= 100)),
    CONSTRAINT files_file_path_check CHECK ((char_length(file_path) <= 2000))
);

-- Create file_items table
CREATE TABLE IF NOT EXISTS public.file_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    content TEXT NOT NULL DEFAULT '',
    tokens INTEGER NOT NULL DEFAULT 0,
    content_embedding VECTOR(1536)
);

-- Create presets table
CREATE TABLE IF NOT EXISTS public.presets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Preset',
    model_id TEXT NOT NULL DEFAULT 'gpt-3.5-turbo',
    temperature REAL NOT NULL DEFAULT 0.5,
    context_length INTEGER NOT NULL DEFAULT 4000,
    include_profile_context BOOLEAN NOT NULL DEFAULT TRUE,
    include_workspace_instructions BOOLEAN NOT NULL DEFAULT TRUE,
    prompt TEXT NOT NULL DEFAULT 'You are a helpful AI assistant.',
    CONSTRAINT presets_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT presets_model_id_check CHECK ((char_length(model_id) <= 100))
);

-- Create assistants table
CREATE TABLE IF NOT EXISTS public.assistants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Assistant',
    description TEXT NOT NULL DEFAULT '',
    model_id TEXT NOT NULL DEFAULT 'gpt-3.5-turbo',
    prompt TEXT NOT NULL DEFAULT 'You are a helpful AI assistant.',
    temperature REAL NOT NULL DEFAULT 0.5,
    context_length INTEGER NOT NULL DEFAULT 4000,
    include_profile_context BOOLEAN NOT NULL DEFAULT TRUE,
    include_workspace_instructions BOOLEAN NOT NULL DEFAULT TRUE,
    embeddings_provider TEXT NOT NULL DEFAULT 'openai',
    sharing TEXT NOT NULL DEFAULT 'private',
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT assistants_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT assistants_model_id_check CHECK ((char_length(model_id) <= 100)),
    CONSTRAINT assistants_embeddings_provider_check CHECK ((char_length(embeddings_provider) <= 100)),
    CONSTRAINT assistants_sharing_check CHECK (((sharing)::text = ANY ((ARRAY['private'::character varying, 'workspace'::character varying, 'public'::character varying])::text[])))
);

-- Create chats table
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES folders(id) ON DELETE CASCADE,
    assistant_id UUID REFERENCES assistants(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Chat',
    model_id TEXT NOT NULL DEFAULT 'gpt-3.5-turbo',
    prompt TEXT NOT NULL DEFAULT 'You are a helpful AI assistant.',
    temperature REAL NOT NULL DEFAULT 0.5,
    context_length INTEGER NOT NULL DEFAULT 4000,
    include_profile_context BOOLEAN NOT NULL DEFAULT TRUE,
    include_workspace_instructions BOOLEAN NOT NULL DEFAULT TRUE,
    embeddings_provider TEXT NOT NULL DEFAULT 'openai',
    sharing TEXT NOT NULL DEFAULT 'private',
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chats_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT chats_model_id_check CHECK ((char_length(model_id) <= 100)),
    CONSTRAINT chats_embeddings_provider_check CHECK ((char_length(embeddings_provider) <= 100)),
    CONSTRAINT chats_sharing_check CHECK (((sharing)::text = ANY ((ARRAY['private'::character varying, 'workspace'::character varying, 'public'::character varying])::text[])))
);

-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    content TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL,
    model TEXT,
    sequence_number INTEGER NOT NULL,
    tokens INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT messages_role_check CHECK (((role)::text = ANY ((ARRAY['user'::character varying, 'assistant'::character varying, 'system'::character varying, 'function'::character varying])::text[]))),
    CONSTRAINT messages_model_check CHECK ((char_length(model) <= 100)),
    CONSTRAINT messages_user_id_chat_id_sequence_number_key UNIQUE (user_id, chat_id, sequence_number)
);

-- Create prompts table
CREATE TABLE IF NOT EXISTS public.prompts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES folders(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Prompt',
    content TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    sharing TEXT NOT NULL DEFAULT 'private',
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT prompts_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT prompts_sharing_check CHECK (((sharing)::text = ANY ((ARRAY['private'::character varying, 'workspace'::character varying, 'public'::character varying])::text[])))
);

-- Create collections table
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    name TEXT NOT NULL DEFAULT 'New Collection',
    description TEXT NOT NULL DEFAULT '',
    sharing TEXT NOT NULL DEFAULT 'private',
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT collections_name_check CHECK ((char_length(name) <= 100)),
    CONSTRAINT collections_sharing_check CHECK (((sharing)::text = ANY ((ARRAY['private'::character varying, 'workspace'::character varying, 'public'::character varying])::text[])))
);

-- Create collection_files junction table
CREATE TABLE IF NOT EXISTS public.collection_files (
    collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (collection_id, file_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles (user_id);
CREATE INDEX IF NOT EXISTS idx_workspaces_user_id ON public.workspaces (user_id);
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON public.folders (user_id);
CREATE INDEX IF NOT EXISTS idx_folders_workspace_id ON public.folders (workspace_id);
CREATE INDEX IF NOT EXISTS idx_files_user_id ON public.files (user_id);
CREATE INDEX IF NOT EXISTS idx_files_workspace_id ON public.files (workspace_id);
CREATE INDEX IF NOT EXISTS idx_files_folder_id ON public.files (folder_id);
CREATE INDEX IF NOT EXISTS idx_file_items_file_id ON public.file_items (file_id);
CREATE INDEX IF NOT EXISTS idx_presets_user_id ON public.presets (user_id);
CREATE INDEX IF NOT EXISTS idx_assistants_user_id ON public.assistants (user_id);
CREATE INDEX IF NOT EXISTS idx_chats_user_id ON public.chats (user_id);
CREATE INDEX IF NOT EXISTS idx_chats_workspace_id ON public.chats (workspace_id);
CREATE INDEX IF NOT EXISTS idx_chats_folder_id ON public.chats (folder_id);
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON public.messages (user_id);
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages (chat_id);
CREATE INDEX IF NOT EXISTS idx_prompts_user_id ON public.prompts (user_id);
CREATE INDEX IF NOT EXISTS idx_prompts_workspace_id ON public.prompts (workspace_id);
CREATE INDEX IF NOT EXISTS idx_prompts_folder_id ON public.prompts (folder_id);
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections (user_id);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.file_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_files ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Profiles
CREATE POLICY "Allow full access to own profiles"
    ON public.profiles
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Workspaces
CREATE POLICY "Allow full access to own workspaces"
    ON public.workspaces
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Folders
CREATE POLICY "Allow full access to own folders"
    ON public.folders
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Files
CREATE POLICY "Allow full access to own files"
    ON public.files
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- File Items
CREATE POLICY "Allow full access to own file items"
    ON public.file_items
    USING (EXISTS (SELECT 1 FROM public.files WHERE files.id = file_items.file_id AND files.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.files WHERE files.id = file_items.file_id AND files.user_id = auth.uid()));

-- Presets
CREATE POLICY "Allow full access to own presets"
    ON public.presets
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Assistants
CREATE POLICY "Allow full access to own assistants"
    ON public.assistants
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Chats
CREATE POLICY "Allow full access to own chats"
    ON public.chats
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Messages
CREATE POLICY "Allow full access to own messages"
    ON public.messages
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Prompts
CREATE POLICY "Allow full access to own prompts"
    ON public.prompts
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Collections
CREATE POLICY "Allow full access to own collections"
    ON public.collections
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Collection Files
CREATE POLICY "Allow full access to own collection files"
    ON public.collection_files
    USING (EXISTS (SELECT 1 FROM public.collections WHERE collections.id = collection_files.collection_id AND collections.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.collections WHERE collections.id = collection_files.collection_id AND collections.user_id = auth.uid()));

-- Create triggers for updated_at
CREATE OR REPLACE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_workspaces_updated_at
BEFORE UPDATE ON public.workspaces
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_folders_updated_at
BEFORE UPDATE ON public.folders
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_files_updated_at
BEFORE UPDATE ON public.files
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_file_items_updated_at
BEFORE UPDATE ON public.file_items
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_presets_updated_at
BEFORE UPDATE ON public.presets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_assistants_updated_at
BEFORE UPDATE ON public.assistants
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_chats_updated_at
BEFORE UPDATE ON public.chats
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_messages_updated_at
BEFORE UPDATE ON public.messages
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_prompts_updated_at
BEFORE UPDATE ON public.prompts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_collections_updated_at
BEFORE UPDATE ON public.collections
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for profile creation when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, username, display_name, bio, profile_context, image_url, image_path, has_onboarded, use_azure_openai)
  VALUES (
    NEW.id,
    'user' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
    'User',
    '',
    '',
    '',
    '',
    FALSE,
    FALSE
  );
  
  -- Create a default workspace for the new user
  INSERT INTO public.workspaces (user_id, name, description, is_home)
  VALUES (
    NEW.id,
    'My Workspace',
    'Your personal workspace',
    TRUE
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create storage bucket for profile images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile_images', 'profile_images', true, 5242880, '{"image/jpeg","image/png","image/gif"}');

-- Set up storage policies
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'profile_images');
CREATE POLICY "Authenticated users can upload files" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'profile_images');
CREATE POLICY "Users can update their own files" ON storage.objects FOR UPDATE USING (auth.uid() = owner) WITH CHECK (bucket_id = 'profile_images');
CREATE POLICY "Users can delete their own files" ON storage.objects FOR DELETE USING (auth.uid() = owner);
