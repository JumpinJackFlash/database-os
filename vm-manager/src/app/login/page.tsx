'use client'

import { useState } from "react";
import { Button, Input } from "@nextui-org/react";
import { Form } from "@nextui-org/form";
import {Icon} from "@iconify/react";
import { createUserSession } from "@/utls/serverActions";
import { useRouter } from 'next/navigation';

export default function LoginPage(props: any) 
{
  const { serviceTitle } = props;

  const [isVisible, setIsVisible] = useState(false);

  const router = useRouter();

  const toggleVisibility = () => setIsVisible(!isVisible);

  function handleSubmit(event: React.FormEvent<HTMLFormElement>)
  {
    event.preventDefault();
    const identification = (event.currentTarget.elements[0] as HTMLInputElement).value;
    const password = (event.currentTarget.elements[1] as HTMLInputElement).value;
    createUserSession(identification, password).then((response) =>
    {
      if (response.ok) router.push('/virtualMachines');
    });
  };

  return(
    <>
      <div className="flex h-full w-full items-center justify-center">
        <div className="flex w-full max-w-sm flex-col gap-4 rounded-large px-8 pb-10 pt-6">
          {serviceTitle}
          <p className="pb-4 text-left text-3xl font-semibold">
            Log In
            <span aria-label="emoji" className="ml-2" role="img">
              👋
            </span>
          </p>
          <Form className="flex flex-col gap-4" validationBehavior="native" onSubmit={handleSubmit}>
            <Input
              isRequired
              label="Identification"
              labelPlacement="outside"
              name="identification"
              placeholder="Enter your identification (username or email)"
              type="text"
              variant="bordered"
            />
            <Input
              isRequired
              endContent={
                <button type="button" onClick={toggleVisibility}>
                  {isVisible ? (
                    <Icon
                      className="pointer-events-none text-2xl text-default-400"
                      icon="solar:eye-closed-linear"
                    />
                  ) : (
                    <Icon
                      className="pointer-events-none text-2xl text-default-400"
                      icon="solar:eye-bold"
                    />
                  )}
                </button>
              }
              label="Password"
              labelPlacement="outside"
              name="password"
              placeholder="Enter your password"
              type={isVisible ? "text" : "password"}
              variant="bordered"
            />
            <Button className="w-full" color="primary" type="submit">
              Log In
            </Button>
          </Form>
        </div>
      </div>    
    </>
  );
}