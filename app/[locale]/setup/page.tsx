"use client"

import { ChatbotUIContext } from "@/context/context"
import { getProfileByUserId, updateProfile } from "@/db/profile"
import {
  getHomeWorkspaceByUserId,
  getWorkspacesByUserId
} from "@/db/workspaces"
import {
  fetchHostedModels,
  fetchOpenRouterModels
} from "@/lib/models/fetch-models"
import { supabase } from "@/lib/supabase/browser-client"
import { TablesUpdate } from "@/supabase/types"
import { useRouter } from "next/navigation"
import { useContext, useEffect, useState } from "react"
import { toast } from "sonner"
import { FinishStep } from "../../../components/setup/finish-step"
import { ProfileStep } from "../../../components/setup/profile-step"
import { StepContainer } from "../../../components/setup/step-container"

export default function SetupPage() {
  const {
    profile,
    setProfile,
    setWorkspaces,
    setSelectedWorkspace,
    setEnvKeyMap,
    setAvailableHostedModels,
    setAvailableOpenRouterModels
  } = useContext(ChatbotUIContext)

  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [currentStep, setCurrentStep] = useState(1)

  // Profile Step
  const [displayName, setDisplayName] = useState("")
  const [username, setUsername] = useState(profile?.username || "")
  const [usernameAvailable, setUsernameAvailable] = useState(false)
  const [isUsernameValid, setIsUsernameValid] = useState(false)

  // Add username validation effect
  useEffect(() => {
    const isValid =
      username &&
      username.length >= 3 && // Minimum username length
      username.length <= 50 && // Maximum username length
      /^[a-zA-Z0-9_]+$/.test(username) // Only letters, numbers, and underscores
    setIsUsernameValid(!!isValid)
  }, [username])

  // API Step
  const [useAzureOpenai, setUseAzureOpenai] = useState(false)
  const [openaiAPIKey, setOpenaiAPIKey] = useState("")
  const [openaiOrgID, setOpenaiOrgID] = useState("")
  const [azureOpenaiAPIKey, setAzureOpenaiAPIKey] = useState("")
  const [azureOpenaiEndpoint, setAzureOpenaiEndpoint] = useState("")
  const [azureOpenai35TurboID, setAzureOpenai35TurboID] = useState("")
  const [azureOpenai45TurboID, setAzureOpenai45TurboID] = useState("")
  const [azureOpenai45VisionID, setAzureOpenai45VisionID] = useState("")
  const [azureOpenaiEmbeddingsID, setAzureOpenaiEmbeddingsID] = useState("")
  const [anthropicAPIKey, setAnthropicAPIKey] = useState("")
  const [googleGeminiAPIKey, setGoogleGeminiAPIKey] = useState("")
  const [mistralAPIKey, setMistralAPIKey] = useState("")
  const [groqAPIKey, setGroqAPIKey] = useState("")
  const [perplexityAPIKey, setPerplexityAPIKey] = useState("")
  const [openrouterAPIKey, setOpenrouterAPIKey] = useState("")

  useEffect(() => {
    ;(async () => {
      const session = (await supabase.auth.getSession()).data.session

      if (!session) {
        return router.push("/login")
      } else {
        const user = session.user

        const profile = await getProfileByUserId(user.id)
        setProfile(profile)
        setUsername(profile.username)

        if (!profile.has_onboarded) {
          setLoading(false)
        } else {
          const data = await fetchHostedModels(profile)

          if (!data) return

          setEnvKeyMap(data.envKeyMap)
          setAvailableHostedModels(data.hostedModels)

          if (profile["openrouter_api_key"] || data.envKeyMap["openrouter"]) {
            const openRouterModels = await fetchOpenRouterModels()
            if (!openRouterModels) return
            setAvailableOpenRouterModels(openRouterModels)
          }

          const homeWorkspaceId = await getHomeWorkspaceByUserId(
            session.user.id
          )
          return router.push(`/${homeWorkspaceId}/chat`)
        }
      }
    })()
  }, [])

  const handleShouldProceed = (proceed: boolean) => {
    if (proceed) {
      if (currentStep === 1) {
        // Validate the form before proceeding
        if (!username || !usernameAvailable) {
          toast.error("Please enter a valid username")
          return
        }
        // Skip directly to finish step since we removed the API step
        setCurrentStep(2)
      } else if (currentStep === 2) {
        // On the finish step, save settings and proceed to chat
        handleSaveSetupSetting()
      }
    } else {
      setCurrentStep(currentStep - 1)
    }
  }

  const handleSaveSetupSetting = async () => {
    try {
      const session = (await supabase.auth.getSession()).data.session
      if (!session) {
        toast.error("Session expired. Please log in again.")
        return router.push("/login")
      }

      const user = session.user
      const profile = await getProfileByUserId(user.id)

      if (!profile) {
        toast.error("Failed to load profile. Please try again.")
        return
      }

      const updateProfilePayload: TablesUpdate<"profiles"> = {
        ...profile,
        has_onboarded: true,
        display_name: displayName,
        username: username.toLowerCase().trim(),
        // Use environment variables for all API keys
        openai_api_key: process.env.OPENAI_API_KEY || "",
        openai_organization_id: process.env.OPENAI_ORGANIZATION_ID || "",
        anthropic_api_key: process.env.ANTHROPIC_API_KEY || "",
        google_gemini_api_key: process.env.GOOGLE_GEMINI_API_KEY || "",
        mistral_api_key: process.env.MISTRAL_API_KEY || "",
        groq_api_key: process.env.GROQ_API_KEY || "",
        perplexity_api_key: process.env.PERPLEXITY_API_KEY || "",
        openrouter_api_key: process.env.OPENROUTER_API_KEY || "",
        use_azure_openai: false,
        azure_openai_api_key: "",
        azure_openai_endpoint: "",
        azure_openai_35_turbo_id: "",
        azure_openai_45_turbo_id: "",
        azure_openai_45_vision_id: "",
        azure_openai_embeddings_id: ""
      }

      const updatedProfile = await updateProfile(
        profile.id,
        updateProfilePayload
      )
      setProfile(updatedProfile)

      const workspaces = await getWorkspacesByUserId(profile.user_id)
      const homeWorkspace = workspaces.find(w => w.is_home)

      // There will always be a home workspace
      setSelectedWorkspace(homeWorkspace!)
      setWorkspaces(workspaces)

      return router.push(`/${homeWorkspace?.id}/chat`)
    } catch (error) {
      console.error("Error saving profile:", error)
      toast.error("Failed to save profile. Please try again.")
    }
  }

  const renderStep = (stepNum: number) => {
    switch (stepNum) {
      // Profile Step
      case 1:
        return (
          <StepContainer
            stepDescription="Let's create your profile."
            stepNum={currentStep}
            stepTitle="Welcome to Chatbot UI"
            onShouldProceed={handleShouldProceed}
            showNextButton={isUsernameValid && usernameAvailable}
            showBackButton={false}
          >
            <ProfileStep
              username={username}
              usernameAvailable={usernameAvailable}
              displayName={displayName}
              onUsernameAvailableChange={setUsernameAvailable}
              onUsernameChange={setUsername}
              onDisplayNameChange={setDisplayName}
            />
          </StepContainer>
        )

      // Finish Step (previously step 3, now step 2)
      case 2:
        return (
          <StepContainer
            stepDescription="You are all set up!"
            stepNum={currentStep}
            stepTitle="Setup Complete"
            onShouldProceed={handleShouldProceed}
            showNextButton={true}
            showBackButton={true}
          >
            <FinishStep displayName={displayName} />
          </StepContainer>
        )
      default:
        return null
    }
  }

  if (loading) {
    return null
  }

  return (
    <div className="flex h-full items-center justify-center">
      {renderStep(currentStep)}
    </div>
  )
}
